
module Text::Fortune:ver<0.01>;

class X::Flags::UnknownFlag is Exception {
  has $.flag;
  method message { "Unknown flag '$.flag'." }
}

class Flags {
  has EnumMap $!em;
  has SetHash $!sh;
  method new($map, *@sets) {
    self.bless(:$map, :@sets);
  }
  submethod BUILD (:$map, :@sets) {
    $!em = enum ( $map.list );
    $!sh .= new;
    self.set( @sets );
  }
  method _set(Bool $tf, *@sets) {
    for @sets -> $s {
      unless $!em{$s} :exists {
        X::Flags::UnknownFlag.new(flag => $s).throw;
      }
      $!sh{$s} = $tf;
      self;
    }
    method set(*@sets) { $._set( True, @sets ) }
    method clear(*@sets) { $._set( False, @sets ) }
  }
  method Int { [+] $!sh.keys.map: { $!em{ $^k } } };
  method from-int(Int $n) {
    for $!em.kv -> $k, $v {
      $!sh{$k} = True if $n +& $v;
    }
    self;
  }
  method flag ($f --> Bool) {
    unless $!em{$f} :exists {
      X::Flags::UnknownFlag.new(flag => $f).throw;
    }
    $!sh{$f};
  }
  method flags { $!em.keys }
  method set-flags { $!sh.keys }
}

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

  my $DAT_FLAGS =  [ random => 1, ordered => 2, rotated => 4 ];

  has Int $.version = 2;
  has Int $.count = 0;
  has Int $.longest = 0;
  has Int $.shortest = 0xFFFFFFFF;
  has Text::Fortune::Flags $!flags;
  has Str $.delimiter;
  has Int @!offset;

  method flags-to-int { $!flags.Int }

  method flags-from-int( Int $flags ) { $!flags.from-int( $flags ).set-flags }

  method flag($f) { $!flags.flag($f); }
  method set-flags { $!flags.set-flags }

  method offset-at ( Int $at ) {
    @!offset[$at];
  }

  method bytelength-of ( Int $at ) {
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

    if $ordered | $random {
      X::Index::Unsupported.new.throw;
    }

    $!flags = Flags.new(
      $DAT_FLAGS.list, (:$rotated, :$ordered, :$random).map({$_.key if $_.value})
    );
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
        $len += $line.bytes
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

      $.flags-from-int( $dat.read(4).unpack('N') );

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

  method flags { %!flags.keys };
  method flag($f) { %!flags{$f} };

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

    my %f = $!index.set-flags X=> True;
    %f<rotated> = True if $rotated.defined;
    %!flags := Set.new( %f.keys  );
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

  method random {
    $.get-fortune( $.count.rand.Int );
  }

  method get-fortune ( Int $n ) {
    my $fortune = $.get-from-offset( $!index.offset-at( $n ) );
    if %!flags<rotated> {
      $fortune .= trans( 'n..za..mN..ZA..M' => 'a..zA..Z' );
    }
    $fortune;
  }

}
