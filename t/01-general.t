#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;

is(kx(undef)      , 'undef'          );
is(kx(1.5)        , '1.5'            );
is(kx("a\nb")     , '"a\nb"'         );
is(kx(\*STDOUT)   , '\*main::STDOUT' );
is(kx("Doolis")   , "'Doolis'"       );
is(kx(12345)      , "12345"          );
is(kx("")         , "''"             );
is(kx("a'b")      , "\"a'b\""        );
is(kx('a"b')      , "'a\"b'"         );
is(kx(0)          , "0"              );
is(kx('0')        , "0"              );
is(kx("1\x{0}2")  , '"1\x{00}2"'     ); # Null byte in the middle of a string
is(kx("+9.3")     , '9.3'            );
is(kx("-9.3")     , '-9.3'           );
is(kx("+3")       , '3'              );
is(kx("-3")       , '-3'             );

# Regexps
is(kx(qr((foo)?(bar))), 'qr(?^:(foo)?(bar))' );
is(kx(qr(^(foo)))     , 'qr(?^:^(foo))'      );
is(kx(qr(foo$))       , 'qr(?^:foo$)'        );

# Array references
is(kx([1,2,3])       , '[1, 2, 3]'     );
is(kx(["one","two"]) , "['one', 'two']");
is(kx( [ '' ] )      , "['']"          );
is(kx( [ 0 ] )       , "[0]"           );
is(kx( [ \0 ] )      , "[\\'0']"       ); # Scalar ref
is(kx( [ undef ] )   , "[undef]"       );

# Unprintable chars
is(kx("\t\t")  , '"\t\t"'  , "Testing \\t");
is(kx("\n\n")  , '"\n\n"'  , "Testing \\n");
is(kx("\r\r")  , '"\r\r"'  , "Testing \\r");
is(kx("\n\r\t"), '"\n\r\t"', "Testing \\n\\r\\t");

# Long unprintable
my $short = "\x{1a}" x 10;
my $long  = "\x{1a}" x 50;
is(kx($short), '"\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}\x{1A}"', "Short string of unprintable chars");
is(kx($long) , "pack('H*', '1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A1A')", "Long string of unprintable chars");

# Booleans
is(kx(!!1) , 'true' );
is(kx(!!0) , 'false');

# Raw array
is(kx(1,2,3)        , '(1, 2, 3)');
is(kx("cat", "dog") , "('cat', 'dog')");

# This is really an error???
is(kx() , "()");

# Empty hash/array
is(kx( [ ] ) , '[]');
is(kx( { } ) , '{}');

# Scalar ref
my $str = "foobar";
is(kx(\$str)    , "\\'foobar'");
is(kx(\"scott") , "\\'scott'");

# Hashes
is(kx({a => 1, b=>2}) , "{ a => 1, b => 2 }");
is(kx({one => 1})     , "{ one => 1 }");
is(kx({'a b' => 1})   , '{ \'a b\' => 1 }');
is(kx({'a"b' => 1})   , '{ \'a"b\' => 1 }');
is(kx({"a'b" => 1})   , '{ \'a\'b\' => 1 }');

# Code reference
is(kx(\&done_testing) , 'sub { ... }');

done_testing();
