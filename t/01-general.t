#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;
$Dump::Krumo::WIDTH         = 100; # Not the terminal width, so tests are reproducible anywhere

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
is(kx({"a'b" => 1})   , '{ "a\'b" => 1 }');

# Code reference
is(kx(\&done_testing) , 'sub { ... }');

# Version strings (vstrings) -- currently dumped as their raw bytes
my $vstr = v10.20;
is(kx($vstr), '"\n\x{14}"', "vstring of printable and unprintable chars");

# Numbers that are not plain integers or decimals. looks_like_number() says
# these are numbers, but the is_integer()/is_float() checks do not match them,
# so they fall through to the "Unknown variable type" branch.
TODO: {
	local $TODO = "numbers outside the is_integer()/is_float() patterns fall through to Unknown variable type";

	unlike(kx("1e10"),  qr/Unknown variable type/, "exponent without a decimal point");
	unlike(kx("1.5e10"), qr/Unknown variable type/, "float with an exponent");
	unlike(kx("Inf"),   qr/Unknown variable type/, "positive infinity");
	unlike(kx("-Inf"),  qr/Unknown variable type/, "negative infinity");
	unlike(kx(0 + "nan"), qr/Unknown variable type/, "NaN");
}

# Keys that need quoting go through quote_string(), so embedded quotes are
# handled properly
is(kx({'a b' => 1}), '{ \'a b\' => 1 }', "hash key containing a space");
is(kx({"a'b" => 1}), '{ "a\'b" => 1 }', "hash key containing a single quote");
is(kx({'a"b' => 1}), '{ \'a"b\' => 1 }', "hash key containing a double quote");

# quote_string() escapes the interpolation sigils when it emits double quotes
is(kx({'a$b' => 1}), '{ "a\\$b" => 1 }', "hash key containing a dollar sign");
is(kx({'a@b' => 1}), '{ "a\@b" => 1 }', "hash key containing an at sign");
is(kx({'a\b' => 1}), '{ "a\\\\b" => 1 }', "hash key containing a backslash");

is(kx('a$b')  , '"a\\$b"', "scalar string containing a dollar sign");
is(kx('a@b')  , '"a\\@b"', "scalar string containing an at sign");

# Dumping a hash of hostile keys round-trips: the output must be valid
# Perl that, when evaluated, reproduces the original hash
{
	my $orig  = { "a'b" => 1, 'c"d' => 2, 'e$f' => 3, 'g@h' => 4, 'i\j' => 5 };

	my %copy  = %{ eval('+' . kx($orig)) };
	is($@      , '', "dumped hash evaluates cleanly");
	is_deeply(\%copy, $orig, "dumped hash round-trips");
}

done_testing();
