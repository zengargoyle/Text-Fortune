use Test;
plan *;

use Text::Fortune;
let $*CWD = 't/test_data';

given Text::Fortune::File.new( path => 'with_dat') {
  is .count, 3, 'got out count';
  is .get-from-offset(0), "a\n", 'got first fortune';
  is .get-from-offset(9), "a\nb\nc\n", 'got last fortune';
  is .get-fortune(0), "a\n", 'got first fortune';
  is .get-fortune(2), "a\nb\nc\n", 'got last fortune';
}
given Text::Fortune::File.new( path => 'without_dat') {
  is .count, 3, 'got out count';
  is .get-from-offset(0), "a\n", 'got first fortune';
  is .get-from-offset(9), "a\nb\nc\n", 'got last fortune';
  is .get-fortune(0), "a\n", 'got first fortune';
  is .get-fortune(2), "a\nb\nc\n", 'got last fortune';
}
given Text::Fortune::File.new( path => 'with_dat', rotated => True) {
  is .flag(<rotated>), True, 'forced rotation';
  is .get-fortune(0), "n\n", 'got first fortune';
  is .get-fortune(2), "n\no\np\n", 'got last fortune';
}

done;
