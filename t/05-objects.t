#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;
$Dump::Krumo::WIDTH         = 100; # Not the terminal width, so tests are reproducible anywhere

package My::Obj;
sub new { return(bless({ a => 1, b => [2, 3] }, shift)); }

package My::Arr;
sub new { return(bless([1, 2], shift)); }

package My::Scalar;
sub new { my $x = "str"; return(bless(\$x, shift)); }

package My::Code;
sub new { return(bless(\&helper, shift)); }
sub helper { return(1); }

package My::Glob;
sub new { return(bless(\*STDOUT, shift)); }

package My::Regexp;
sub new { return(bless(qr/foo/, shift)); }

package main;

my $obj   = My::Obj->new;
my $obj_a = My::Arr->new;
my $obj_s = My::Scalar->new;
my $obj_c = My::Code->new;
my $obj_g = My::Glob->new;
my $obj_r = My::Regexp->new;

# Objects are dumped as "Class" :: <contents>
is(kx($obj),   '"My::Obj" :: { a => 1, b => [2, 3] }', "blessed hash object");
is(kx($obj_a), '"My::Arr" :: [1, 2]',                  "blessed array object");
is(kx($obj_s), '"My::Scalar" :: \'str\'',              "blessed scalar object");

# Anything we cannot break down is dumped as a plain string
is(kx($obj_c), '"My::Code" :: \'Unknown class?\'',     "blessed coderef object");
is(kx($obj_g), '"My::Glob" :: \'Unknown class?\'',     "blessed glob object");
is(kx($obj_r), '"My::Regexp" :: \'Unknown class?\'',   "blessed regexp object");

# Objects nested inside other structures
is(kx({ obj => $obj }), '{ obj => "My::Obj" :: { a => 1, b => [2, 3] } }', "object as a hash value");
is(kx([$obj]),           '["My::Obj" :: { a => 1, b => [2, 3] }]',        "object as an array value");
is(kx({ obj => My::Obj->new, arr => [$obj_a] }),
	'{ arr => ["My::Arr" :: [1, 2]], obj => "My::Obj" :: { a => 1, b => [2, 3] } }',
	"multiple objects in one structure");

# An object inside an object
{
	package My::Inner;
	sub new { return(bless([42], shift)); }

	package My::Outer;
	sub new { return(bless({ inner => My::Inner->new }, shift)); }
}

is(kx(My::Outer->new), '"My::Outer" :: { inner => "My::Inner" :: [42] }', "nested objects");

# Column mode with objects -- the class name accounts for the extra width
{
	local $Dump::Krumo::WIDTH = 30;

	my $expected = <<'EOS';
{
  k => "My::Obj" :: {
    a => 1,
    b => [
      2,
      3,
    ],
  },
}
EOS
	chomp($expected);

	is(kx({ k => $obj }), $expected, "object content wraps in column mode");
}

# A long class name pushes the contents into column mode
{
	local $Dump::Krumo::WIDTH = 25;

	my $long_class = bless({ a => 1 }, "A::Very::Long::Package::Name");

	my $expected = <<'EOS';
{
  k => "A::Very::Long::Package::Name" :: {
    a => 1,
  },
}
EOS
	chomp($expected);

	is(kx({ k => $long_class }), $expected, "long class name wraps in column mode");
}

################################################################################
# JSON::PP::Boolean and $promote_bool
################################################################################

SKIP: {
	skip("JSON::PP is not installed", 8) unless(eval { require JSON::PP; 1 });

	my $true  = JSON::PP::true();
	my $false = JSON::PP::false();

	is(kx($true),  "true",  "promote_bool=1: JSON::PP::true");
	is(kx($false), "false", "promote_bool=1: JSON::PP::false");

	is(kx({ t => $true, f => $false }), '{ f => false, t => true }',
		"promote_bool=1: booleans inside a hash");

	is(kx([$true, $false]), "[true, false]", "promote_bool=1: booleans inside an array");

	{
		local $Dump::Krumo::promote_bool = 0;

		# Without promotion the object is dumped like any other class. The exact
		# value depends on whether the internal scalar has been stringified
		# before the dump, so we only check the class prefix here.
		like(kx($true), qr/^"JSON::PP::Boolean" :: /, "promote_bool=0: JSON::PP::true is an object");
		like(kx($false), qr/^"JSON::PP::Boolean" :: /, "promote_bool=0: JSON::PP::false is an object");

		like(kx({ t => $true }), qr/^\{ t => "JSON::PP::Boolean" :: /, "promote_bool=0: object in a hash");
	}

	# The booleans are promoted again once the local goes out of scope
	is(kx($true), "true", "promote_bool is restored");
}

done_testing();
