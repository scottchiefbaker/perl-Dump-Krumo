#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;
$Dump::Krumo::WIDTH         = 100; # Not the terminal width, so tests are reproducible anywhere

my $data = {
	name    => "Scott",
	address => { city => "Portland", zip => "97201" },
	tags    => ["a", "b", "c"],
};

# Everything fits on one line at 100 columns
is(kx($data),
	"{ address => { city => 'Portland', zip => 97201 }, name => 'Scott', tags => ['a', 'b', 'c'] }",
	"nested structure renders inline at 100 columns");

# Column mode at 60 columns
{
	local $Dump::Krumo::WIDTH = 60;
	my $expected = <<'EOS';
{
  address => { city => 'Portland', zip => 97201 },
  name    => 'Scott',
  tags    => ['a', 'b', 'c'],
}
EOS
	chomp($expected);
	is(kx($data), $expected, "column mode at WIDTH=60");
}

# Column mode at 40 columns -- nested hash also wraps, and the keys align
{
	local $Dump::Krumo::WIDTH = 40;
	my $expected = <<'EOS';
{
  address => {
    city => 'Portland',
    zip  => 97201,
  },
  name    => 'Scott',
  tags    => ['a', 'b', 'c'],
}
EOS
	chomp($expected);
	is(kx($data), $expected, "nested column mode at WIDTH=40");
}

# Column mode at 30 columns -- the array wraps too
{
	local $Dump::Krumo::WIDTH = 30;
	my $expected = <<'EOS';
{
  address => {
    city => 'Portland',
    zip  => 97201,
  },
  name    => 'Scott',
  tags    => [
    'a',
    'b',
    'c',
  ],
}
EOS
	chomp($expected);
	is(kx($data), $expected, "nested array wraps at WIDTH=30");
}

# A deeply nested structure
{
	local $Dump::Krumo::WIDTH = 25;
	my $expected = <<'EOS';
{
  a => {
    b => {
      c => [1, 2, 3],
    },
  },
}
EOS
	chomp($expected);
	is(kx({ a => { b => { c => [1, 2, 3] } } }), $expected, "deep nesting indents each level");
}

# An array of hashes is small enough to stay inline
{
	local $Dump::Krumo::WIDTH = 30;
	is(kx([ { aa => 1 }, { bb => 2 } ]), "[{ aa => 1 }, { bb => 2 }]",
		"array of hashes stays inline when it fits");
}

# A single very long value still triggers column mode
{
	my $wide = kx([ "x" x 120 ]);

	like($wide, qr/^\[\n/,        "long array opens column mode");
	like($wide, qr/\n\]\z/,       "long array closes column mode");
	like($wide, qr/\n\s+'x{120}',\n/, "long value is on its own line");
}

# $indent_spaces changes the padding used by each nesting level
{
	local $Dump::Krumo::WIDTH = 30;
	local $Dump::Krumo::indent_spaces = 4;
	my $expected = <<'EOS';
{
    a  => 1,
    bb => 22,
    c  => [3, 4],
}
EOS
	chomp($expected);
	is(kx({ a => 1, bb => 22, c => [3, 4] }), $expected, "indent_spaces=4");
}

{
	local $Dump::Krumo::WIDTH = 20;
	local $Dump::Krumo::indent_spaces = 0;
	my $expected = <<'EOS';
{
a => 1,
b => 2,
}
EOS
	chomp($expected);
	is(kx({ a => 1, b => 2 }), $expected, "indent_spaces=0 (no padding)");
}

# $hash_sort controls whether hash keys are sorted before output
{
	my %h = map { $_ => $_ } qw(short longish_key_x medium);

	is(kx(\%h), "{ " . join(", ", map { "$_ => '$_'" } sort(keys(%h)) ) . " }",
		"hash_sort=1 sorts the keys");

	local $Dump::Krumo::hash_sort = 0;

	# The expected output is built from the hash's own key order, since
	# Perl randomizes key order between runs
	my $expected = "{ " . join(", ", map { "$_ => '$_'" } keys(%h) ) . " }";
	is(kx(\%h), $expected, "hash_sort=0 keeps the hash's own key order");
}

# The hash keys line up so the '=>' operators are in the same column
{
	local $Dump::Krumo::WIDTH = 20;

	my $expected = <<'EOS';
{
  a   => 1,
  abc => 2,
}
EOS
	chomp($expected);

	is(kx({ a => 1, abc => 2 }), $expected, "hash keys are aligned in column mode");

	# Keys that need quoting are padded from their raw length, which lines up
	# with the rendered length
	my $key = "a'b";
	$expected = <<'EOS';
{
  'a'    => 1,
  "a'b"  => 2,
  'abcd' => 3,
}
EOS
	chomp($expected);

	is(kx({ a => 1, $key => 2, abcd => 3 }), $expected, "quoted keys are aligned too");
}

################################################################################
# Unit tests for the width estimation helpers
################################################################################

is(Dump::Krumo::array_str_len(1, 2, 3), 3, "array_str_len: three integers");
is(Dump::Krumo::array_str_len("a", "b"), 6, "array_str_len: quotes count for non-numeric strings");
is(Dump::Krumo::array_str_len(),        0, "array_str_len: empty list");
is(Dump::Krumo::max_length(qw(a bb ccc)), 3, "max_length: longest key");
is(Dump::Krumo::max_length(),            0, "max_length: empty list");

# true/false are counted as 4 and 5 chars
is(Dump::Krumo::array_str_len(!!1, !!0, 1, undef), 15, "array_str_len: bools, int and undef");

ok(Dump::Krumo::needs_column_mode(["x" x 120]), "needs_column_mode: wide array needs columns");
ok(!Dump::Krumo::needs_column_mode([1, 2]),   "needs_column_mode: narrow array does not");
ok(!Dump::Krumo::needs_column_mode({ a => 1 }), "needs_column_mode: small hash does not");

# Empty containers never need column mode
ok(!Dump::Krumo::needs_column_mode([]), "needs_column_mode: empty array");
ok(!Dump::Krumo::needs_column_mode({}), "needs_column_mode: empty hash");

# A tiny WIDTH forces column mode even for small data
{
	local $Dump::Krumo::WIDTH = 3;
	ok(Dump::Krumo::needs_column_mode([1, 2, 3]), "needs_column_mode: small WIDTH forces columns");
}

# Blessed objects are estimated by their underlying reftype
{
	my $obj = bless({ a => 1 }, "Foo");

	ok(!Dump::Krumo::needs_column_mode($obj), "needs_column_mode: blessed hash");

	local $Dump::Krumo::WIDTH = 8;
	my $expected = <<'EOS';
{
  k => "Foo" :: {
    a => 1,
  },
}
EOS
	chomp($expected);
	is(kx({ k => $obj }), $expected, "object content wraps inside column mode");
}

done_testing();
