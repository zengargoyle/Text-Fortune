
module Text::Fortune:ver<0.01>;

class X::Index::Unsupported is Exception {
  method message() {
    "Options 'ordered' and 'rotated' are not supported.";
  }
}
class X::Index::NotFound is Exception {
  method message() {
    "not found.";
  }
}
class X::Index::OutOfBounds is Exception {
  method message() {
    "not found.";
  }
}

class Index {

  my enum Flags( random => 1, ordered => 2, rotated => 4 );

  has Int $.version = 2;
  has Int $.count = 0;
  has Int $.longest = 0;
  has Int $.shortest = 0xFFFFFFFF;
  has %!flags;
  has Str $.delimiter;
  has Int @!offset;

  method flags-to-int {
    [+] gather for %!flags.keys {
      take Flags.enums{ $_ } if %!flags{$_};
    }
  }

  method flags-from-int( Int $flags ) {
    Flags.enums.keys.map: { $^a => ?($flags +& Flags.enums{ $^a }) };
  }

  method flags { %!flags; }

  method offset-at ( Int $at ) {
    @!offset[$at];
  }

  method length-of ( Int $at ) {
    if $at >= $!count {
      X::Index::OutOfBounds.new.throw;
    }
    $.offset-at( $at+1 ) - $.offset-at( $at ) - 2;
  }

  submethod BUILD (
    Bool :$rotated = False,
    Bool :$ordered = False,
    Bool :$random = False,
    Str :$!delimiter = '%',
  ) {
    %!flags = :$rotated, :$ordered, :$random;
    if $ordered | $random {
      X::Index::Unsupported.new.throw;
    }
  }

  method load-fortune ($fortunefile) {

    X::Index::NotFound.new.throw unless
      $fortunefile.IO ~~ :e & :!d & :r;

    my $ff = $fortunefile.IO.open :r :!chomp;

    my $stop = $!delimiter ~ "\n";

    while ! $ff.eof {
      my $pos = $ff.tell;
      my $len;
      while $ff.get -> $line {
        last if $line eq $stop;
        $len += $line.chars
      }
      if $len {
        $!longest max= $len;
        $!shortest min= $len;
        $!count++;
        @!offset.push: $pos;
      }
    }
    @!offset.push: $ff.tell;
    self;
  }

  method load-dat ($datfile) {

    X::Index::NotFound.new.throw unless
      $datfile.IO ~~ :e & :!d & :r;

    if $datfile.IO.open :r -> $dat {
      $!version = $dat.read(4).unpack('N');
      $!count = $dat.read(4).unpack('N');
      $!longest = $dat.read(4).unpack('N');
      $!shortest = $dat.read(4).unpack('N');

      %!flags = self.flags-from-int( $dat.read(4).unpack('N') );

      $!delimiter = $dat.read(1).unpack('C').chr;

      $dat.seek(24,0);
      loop (my $i = 0; $i <= $!count; $i++) {
        @!offset.push: $dat.read(4).unpack('N');
      }
    }
    self;
  }

  method Buf {
    my Buf $b;
    $b = pack('N', $!version);
    $b ~= pack('N', $!count);
    $b ~= pack('N', $!longest);
    $b ~= pack('N', $!shortest);

    $b ~= pack('N', $.flags-to-int);
    $b ~= pack('CCCC', $!delimiter.ord, 0, 0, 0);

    if $!count == 0 {
        $b ~= pack('N', 0);
    }
    else {
      for @!offset -> $o {
        $b ~= pack('N', $o);
      }
    }

    $b;
  }
}

class File {
  has $!handle;
  has $!index handles <version count longest shortest delimiter>;
  has %!flags;

  method flags { %!flags };

  submethod BUILD (
    :$path as IO,
    :$index?,
    :$datpath = $path ~ '.dat',
    :$rotated,
  ) {
    unless $path.IO ~~ :e & :!d & :r {
      X::Index::NotFound.new.throw;
    }
    $!handle = $path.IO.open :r :!chomp;

    if $datpath.IO ~~ :e & :!d & :r {
      $!index = Text::Fortune::Index.new.load-dat( $datpath );
    }
    else {
      $!index = Text::Fortune::Index.new.load-fortune( $path );
    }
    %!flags = $!index.flags;
    %!flags<rotated> = $rotated if $rotated.defined;
  }

  method get-from-offset ( Int $o ) {
    my $stop = $!index.delimiter ~ "\n";
    $!handle.seek: $o, 0;
    my Str $content;
    while $!handle.get -> $line {
      last if $line eq $stop;
      $content ~= $line;
    }
    $content;
  }

  method get-fortune ( Int $n ) {
    my $fortune = $.get-from-offset( $!index.offset-at( $n ) );
    if $.flags<rotated> {
      $fortune .= trans(
        'a..m' => 'n..z', 'n..z' => 'a..m',
        'A..M' => 'N..Z', 'N..Z' => 'A..M',
      );
    }
    $fortune;
  }

}
