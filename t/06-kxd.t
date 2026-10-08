#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

# The :short tag exports k() and kd() along with the default kx()/kxd()
use Dump::Krumo qw(:short);

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 0;

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
# The :short exports
################################################################################

is(k(123), "123", "k() is an alias for kx()");
is(k([1, 2]), "[1, 2]", "k() on an array");

my $kd_died = "";
my $kd_ret;
capture_stdout(sub { eval { $kd_ret = kd(123); 1 } or $kd_died = $@; });

is($kd_ret,  undef, "kd() does not return a value");
like($kd_died, qr/Dump::Krumo died/, "kd() is an alias for kxd()");

################################################################################
# kxd()
################################################################################

# kxd() dumps, then dies
my $died = "";
my $ret;
my $out  = capture_stdout(sub {
	eval { $ret = kxd("boom"); 1 } or $died = $@;
});

is($ret,  undef, "kxd() does not return on success");
like($out,  qr/^\n$/, "kxd() prints a blank line of its own");
like($died, qr/^Dump::Krumo died at \S+ line \d+\./, "kxd() dies with the file and line");

# Each call reports the line it was called from
{
	my @died = ();

	capture_stdout(sub {
		eval { kxd("a"); 1 } or push(@died, $@);
		eval { kxd("b"); 1 } or push(@died, $@);
	});

	is(scalar(@died), 2, "each kxd() call dies");
	like($died[0], qr/line \d+\./, "the first death has a line number");
	like($died[1], qr/line \d+\./, "the second death has a line number");
	isnt($died[0], $died[1], "each call reports its own line number");
}

# kxd() on other data types
{
	my @msgs = ();

	capture_stdout(sub {
		eval { kxd([1, 2]);    1 } or push(@msgs, "array");
		eval { kxd({ a => 1 }); 1 } or push(@msgs, "hash");
		eval { kxd();           1 } or push(@msgs, "noargs");
	});

	is(scalar(@msgs), 3, "kxd() dies for arrays, hashes, and no arguments");
}

# kxd() works when disabled
{
	local $Dump::Krumo::disable = 1;

	my $ret = eval { kd("boom") };
	is($ret, -1, "disable: kd() returns -1 and does not die");
	is($@, "", "disable: kd() did not die");
}

# $stack_trace turns the croak into a confess
{
	local $Dump::Krumo::stack_trace = 1;

	my $err = "";
	capture_stdout(sub { eval { kxd("boom") } or $err = $@; });

	like($err, qr/Dump::Krumo died/,            "stack_trace: still dies");
	like($err, qr/Dump::Krumo::kxd\(.*\) called at/, "stack_trace: confess includes the stack");
}

# Print mode: the dump is printed before the die
{
	local $Dump::Krumo::return_string = 0;

	my $out = capture_stdout(sub { eval { kxd("x") } });

	like($out, qr/'x'\n\n/, "print mode: kxd() prints the dump then a blank line");
	like($@,   qr/Dump::Krumo died/, "print mode: kxd() dies");
}

done_testing();
