#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;

is(kx([1,2,3])    , '[1, 2, 3]'    );
is(kx([!!1])      , '[true]'       );
is(kx(undef)      , 'undef'        );
is(kx(1,2,3)      , '(1, 2, 3)'    );
is(kx(1.5)        , '1.5'          );
is(kx("a\nb")     , '"a\nb"'       );
is(kx("\*STDOUT") , '"*STDOUT"'    );
is(kx("Doolis")   , "'Doolis'"     );
is(kx(12345)      , "12345"        );
is(kx("")         , "''"           );
is(kx("a'b")      , "\"a'b\""      );
is(kx(0)          , "0"            );
is(kx('0')        , "0"            );

# This is really an error???
is(kx()           , "()");

# Empty hash/array
is(kx( [ ] ) , '[]');
is(kx( { } ) , '{}');

# Scalar ref
my $str = "foobar";
is(kx(\$str), "\\'foobar'");

# Hashes
is(kx("{a => 1, b=>2}") , '"{a => 1, b=>2}"');
is(kx("{one => 1}")     , '"{one => 1}"');
is(kx("{'a b' => 1}")   , '"{\'a b\' => 1}"');
is(kx("{'a\"b' => 1}")  , '"{\'a"b\' => 1}"');

is(kx(\&done_testing)  , 'sub { ... }');

done_testing();
