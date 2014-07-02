use Test;
plan *;

use Text::Fortune;
let $*CWD = 't/test_data';

my Buf $b = do { my $f = 'empty.dat'.IO.open; $f.read($f.s) };
say $b;

given Text::Fortune::Index.new {
  is .version, 2, 'is version: 2';
  is .Buf, $b, 'matches empty.dat';
}

given Text::Fortune::Index.new(:rotated, delimiter => '@') {
  is .flags-to-int, 4, 'flags might work';
  is .delimiter, '@', 'can set delimiter';
  is .flags<rotated>, True, 'is rotated';
  is .flags<ordered>, False, 'is not ordered';
}

dies_ok { Text::Fortune::Index.new(:ordered) }, 'dies with ordered';

throws_like { Text::Fortune::Index.new(:ordered) },
  X::Index::Unsupported,
  message => rx:s/are not supported/;

done;
