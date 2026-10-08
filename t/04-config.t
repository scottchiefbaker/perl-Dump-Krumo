#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;
$Dump::Krumo::WIDTH         = 100; # Not the terminal width, so tests are reproducible anywhere

# Capture whatever is sent to STDOUT
sub capture_stdout {
	my $code = shift();
	my $out  = "";

	{
		local *STDOUT;
		open(STDOUT, ">", \$out);
		$code->();
	}

	return $out;
}

################################################################################
# $disable
################################################################################

{
	local $Dump::Krumo::disable = 1;

	is(kx(123),      -1, "disable: kx() returns -1 on a scalar");
	is(kx([1, 2]),   -1, "disable: kx() returns -1 on an array");

	my $ret;
	my $out = capture_stdout(sub { $ret = kxd("boom"); });

	is($ret, -1, "disable: kxd() returns -1");
	is($out, "", "disable: kxd() prints nothing");

	$out = capture_stdout(sub { kx({ a => 1 }) });
	is($out, "", "disable: kx() prints nothing");

	# kxd() does not die when disabled
	my $survived = 0;
	$out = capture_stdout(sub { eval { kxd("boom"); $survived = 1 } });

	ok($survived, "disable: kxd() does not die");
	is($@, "", "disable: kxd() did not die");
}

################################################################################
# Print mode ($return_string = 0)
################################################################################

{
	local $Dump::Krumo::return_string = 0;

	my $out = capture_stdout(sub { kx({ a => 1 }) });
	is($out, "{ a => 1 }\n", "print mode: kx() prints with a trailing newline");

	$out = capture_stdout(sub { eval { kxd([1, 2]) } });
	is($out, "[1, 2]\n\n", "print mode: kxd() prints the dump then a blank line");
	like($@, qr/Dump::Krumo died/, "print mode: kxd() dies");

	local $Dump::Krumo::return_string = 1;
	is(kx({ a => 1 }), "{ a => 1 }", "return_string=1 returns the string");
}

################################################################################
# $short_hex
################################################################################

is(kx("\x{01}\x{02}"), '"\x{01}\x{02}"', "short_hex=0: braces around hex escapes");

{
	local $Dump::Krumo::short_hex = 1;

	is(kx("\x{01}\x{02}"), '"\x01\x02"', "short_hex=1: no braces around hex escapes");
	is(kx("\x{7f}"),        '"\x7F"',     "short_hex=1: zero padded to two digits");
}

################################################################################
# $highlight_ansi
################################################################################

my $ansi = "\e[1;32m";

is(kx($ansi), '(\e[1;32m)', "highlight_ansi=1 makes escapes visible");

{
	local $Dump::Krumo::highlight_ansi = 0;

	is(kx($ansi), '"\e[1;32m"', "highlight_ansi=0 dumps the escapes literally");
}

################################################################################
# $COLORS and get_color()
################################################################################

is(Dump::Krumo::get_color("integer"), 33,  "get_color() returns the configured color");
is(Dump::Krumo::get_color("undef"),   196, "get_color() returns the configured color for undef");
is(Dump::Krumo::get_color("nope"),    251, "get_color() falls back to the default color");
is(Dump::Krumo::get_color(""),        251, "get_color() falls back for an empty key");

{
	my %saved = %{$Dump::Krumo::COLORS};

	{
		local $Dump::Krumo::COLORS = { %saved, integer => 100 };
		is(Dump::Krumo::get_color("integer"), 100, "COLORS: overriding a single entry");
	}

	# An entirely custom scheme, and anything missing falls back to the default
	{
		local $Dump::Krumo::COLORS = { integer => 200, string => 201 };
		is(Dump::Krumo::get_color("integer"), 200, "COLORS: replacing the whole scheme");
		is(Dump::Krumo::get_color("undef"),   251, "COLORS: missing types fall back to the default");
	}

	is(Dump::Krumo::get_color("integer"), 33, "COLORS: the original scheme is restored");
}

################################################################################
# $debug
################################################################################

{
	local $Dump::Krumo::debug = 1;

	my $out = capture_stdout(sub { kx({ a => 1 }) });

	like($out, qr/Screen width: \d/, "debug: prints the screen width");
	like($out, qr/Left Indent \| Hash Padding \| Content \| Total/, "debug: prints the table header");
	like($out, qr/^\s*\d+\s+\+\s+\d+\s+\+\s+\d+\s+=\s+\d+\s+\(\d\)/m, "debug: prints a table row");
}

################################################################################
# get_terminal_width()
################################################################################

{
	# With no $TERM, tput cannot run so we report 0 and callers use their default
	local $ENV{TERM} = "";

	is(Dump::Krumo::get_terminal_width(), 0, "get_terminal_width() is 0 without a TERM");
}

ok($Dump::Krumo::WIDTH > 0, "WIDTH is set to a positive number");

################################################################################
# is_nan() / is_infinity()
################################################################################

ok(Dump::Krumo::is_nan(0 + "nan"), "is_nan() detects NaN");
ok(!Dump::Krumo::is_nan(1),        "is_nan() is false for a number");

ok(Dump::Krumo::is_infinity(9**9**9), "is_infinity() detects Inf");
ok(!Dump::Krumo::is_infinity(1),      "is_infinity() is false for a finite number");

################################################################################
# Forced color ($use_color = 2)
#
# These are last on purpose: color() caches its availability in a state
# variable, so once color is forced on it stays on for the rest of the
# process (see the TODO test at the bottom).
################################################################################

{
	local $Dump::Krumo::use_color = 2;

	is(kx(123), "\e[38;5;33m123\e[0m", "use_color=2: forces color on integers");

	{
		local $Dump::Krumo::return_string = 0;

		my $out = capture_stdout(sub { kx({ a => 1 }) });
		is($out, "\e[0m{ \e[38;5;208ma\e[0m => \e[38;5;33m1\e[0m }\n",
			"use_color=2: print mode starts with a reset");
	}

	# The custom colors are picked up by the renderer
	local $Dump::Krumo::COLORS = { %{$Dump::Krumo::COLORS}, integer => 100 };
	is(kx(123), "\e[38;5;100m123\e[0m", "COLORS: renders with a custom color");

	{
		local $Dump::Krumo::use_color = 0;
		TODO: {
			local $TODO = "color() caches its state, so turning color back off does not work";
			is(kx(123), "123", "use_color=0: disables color after it was forced on");
		}
	}
}

done_testing();
