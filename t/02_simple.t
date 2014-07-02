use Test;
plan *;

use Text::Fortune;
let $*CWD = 't/test_data';

throws_like { Text::Fortune::Index.new.load-dat( 'not_found.dat' ) },
  X::Index::NotFound,
  message => rx:s/not found/;

given Text::Fortune::Index.new {
  is .flags-from-int(0),
    %(random => False, ordered => False, rotated => False  ),
    'null flags';
}

given Text::Fortune::Index.new {
  is .flags-from-int(4),
    %(random => False, ordered => False, rotated => True  ),
    'one flag';
}

given Text::Fortune::Index.new {
  is .flags-from-int(5),
    %(random => True, ordered => False, rotated => True  ),
    'two flags';
}

my Buf $b = do { my $f = 'empty.dat'.IO.open; $f.read($f.s) };
given Text::Fortune::Index.new.load-dat( 'empty.dat' ) {
  is .version, 2, 'is version: 2';
  is .count, 0, 'has count: 0';
  is .longest, 0, 'has longest: 0';
  is .shortest, 0xFFFFFFFF, 'has shortest: -1';
  is .flags-to-int, 0, 'has flags: 0';
  is .delimiter, '%', 'has delimiter: %';
  is .offset-at(0), 0, 'only offset is: 0';
  is .Buf, $b, 'serializes correctly';
}

done;
