#!/usr/bin/env perl

use strict;
use warnings;
use v5.16;
use Scalar::Util;

package Dump::Krumo;

use Exporter 'import';
our @EXPORT  = qw(kx);
our $VERSION = 0.1.1;

my $current_indent_level = 0;
our $indent_spaces       = 2;

our $COLORS = {
	'string'       => 230,
	'control_char' => 226,
	'undef'        => 196,
	'hash_key'     => 208,
	'integer'      => 33,
	'float'        => 51,
	'class'        => 118,
	'binary'       => 111,
	'scalar_ref'   => 225,
	'boolean'      => 141,
	'regexp'       => 164,
	'glob'         => 40,
};

my $WIDTH = get_terminal_width();
$WIDTH = 100;

###############################################################################
###############################################################################

sub kx {
	my @arr = @_;

	my @items    = ();
	my $cnt      = scalar(@arr);
	my $is_array = 0;

	# If someone passes in a real array (not ref) we fake it out
	if ($cnt > 1) {
		@arr      = (\@_); # Convert to arrayref
		$is_array = 1;
	}

	# Loop through each item and dump it out
	foreach my $item (@arr) {
		push(@items, __dump($item));
	}

	if (!@items) {
		@items = ("UNKNOWN TYPE");
	}

	my $str = join(", ", @items);

	# If it's a real array we remove the false [ ] added by __dump()
	if ($is_array) {
		my $len = length($str) - 2;
		$str    = substr($str, 1, $len);
	}

	if ($cnt > 1) {
		$str = "($str)";
	}

	print $str . "\n";
}

sub __dump {
	my $x     = shift();
	my $type  = ref($x);
	my $class = Scalar::Util::blessed($x) || "";

	my $ret;

	if ($type eq 'ARRAY') {
		$ret = __dump_array($x);
	} elsif ($type eq 'HASH') {
		$ret = __dump_hash($x);
	} elsif ($type eq 'SCALAR') {
		$ret = color($COLORS->{scalar_ref}, "* Scalar reference");
	} elsif (!$type && is_bool_val($x)) {
		$ret = __dump_bool($x);
	} elsif (!$type && is_integer($x)) {
		$ret = __dump_integer($x);
	} elsif (!$type && is_float($x)) {
		$ret = __dump_float($x);
	} elsif (!$type && is_string($x)) {
		$ret = __dump_string($x);
	} elsif (!$type && is_undef($x)) {
		$ret = __dump_undef();
	} elsif ($class eq "Regexp") {
		$ret = __dump_regexp($class, $x);
	} elsif ($type eq "GLOB") {
		$ret = __dump_glob($class, $x);
	} elsif ($class) {
		$ret = __dump_class($class, $x);
	} else {
		$ret = "BEES? '$type'";
	}

	return $ret;
}

################################################################################
################################################################################

sub __dump_bool {
	my $x = shift();
	my $ret;

	if ($x) {
		$ret = color($COLORS->{boolean}, "true");
	} else {
		$ret = color($COLORS->{boolean}, "false");
	}

	return $ret;
}

sub __dump_regexp {
	my ($class, $x) = @_;

	my $ret = color($COLORS->{regexp}, "qr$x");

	return $ret;
}

sub __dump_glob {
	my ($class, $x) = @_;

	my $ret = color($COLORS->{glob}, $x);

	return $ret;
}

sub __dump_class {
	my ($class, $x) = @_;

	my $ret      = '"' . color($COLORS->{class}, $class) . "\" :: ";
	my $reftype  = Scalar::Util::reftype($x);
	my $y;

	# We need an unblessed copy of the data so we can display it
	if ($reftype eq 'ARRAY') {
		$y = [@$x];
	} elsif ($reftype eq 'HASH') {
		$y = {%$x};
	} elsif ($reftype eq 'SCALAR') {
		$y = $$x;
	} else {
		$y = "Unknown class?";
	}

	$ret .= __dump($y);

	return $ret;
}

sub __dump_integer {
	my $x   = shift();
	my $ret = color($COLORS->{integer}, $x);

	return $ret;
}

sub __dump_float {
	my $x   = shift();
	my $ret = color($COLORS->{float}, $x);

	return $ret;
}

sub __dump_string {
	my $x = shift();

	my $printable = is_printable($x);

	# Convert all \n to printable version
	my $slash_n = color($COLORS->{control_char}, '\\n') . color($COLORS->{string});
	my $slash_r = color($COLORS->{control_char}, '\\r') . color($COLORS->{string});
	my $slash_t = color($COLORS->{control_char}, '\\t') . color($COLORS->{string});

	$x =~ s/\n/$slash_n/g;
	$x =~ s/\r/$slash_r/g;
	$x =~ s/\t/$slash_t/g;

	my $ret = '';

	if (!$printable) {
		$ret = color($COLORS->{binary}, "0x" . unpack("h*", $x));
	# If it's a simple string we single quote it
	} elsif ($x =~ /^[\w .,":-]*$/g) {
		$ret = "'" . color($COLORS->{string}, "$x") . "'";
	# Otherwise we clean it up and then double quote it
	} else {
		# Do some clean up here?
		$ret = '"' . color($COLORS->{string}, "$x") . '"';
	}


	return $ret;
}

sub __dump_undef {
	my $ret = color($COLORS->{undef}, 'undef');

	return $ret;
}

sub __dump_array {
	my $x = shift();

	# If it's only a single element we return the stringified version of that
	if (ref($x) ne 'ARRAY') {
		return __dump("$x");
	}

	$current_indent_level++;

	my $cnt = scalar(@$x);
	if ($cnt == 0) {
		$current_indent_level--;
		return '[]',
	}

	# See if we need to switch to column mode to output this array
	my $column_mode = needs_column_mode($x);

	my $ret = '';
	my @items = ();
	foreach my $z (@$x) {
		push(@items, __dump($z));
	}

	if ($column_mode) {
		$ret = "[\n";
		my $pad = " " x ($current_indent_level * $indent_spaces);
		foreach my $x (@items ) {
			$ret .= $pad . "$x,\n";
		}

		$pad = " " x (($current_indent_level - 1) * $indent_spaces);
		$ret .= $pad . "]";
	} else {
		$ret = '[' . join(", ", @items) . ']';
	}

	$current_indent_level--;

	return $ret;
}

sub __dump_hash {
	my $x = shift();
	$current_indent_level++;

	my $ret;
	my @items = ();
	my @keys  = sort(keys(%$x));
	my @vals  = values(%$x);
	my $cnt   = scalar(@keys);

	if ($cnt == 0) {
		$current_indent_level--;
		return '{}',
	}

	# See if we need to switch to column mode to output this array
	my $column_mode = needs_column_mode($x);
	my $max_length  = 0;

	# If we're too wide for the screen we drop to column mode
	if ($column_mode) {
		$max_length  = max_length(@keys);
	}

	# Loop through each key and build the appropriate string for it
	foreach my $key (@keys) {
		my $val = $x->{$key};

		my $key_str = '';
		if ($key =~ /\W/) {
			$key_str = '"' . color($COLORS->{hash_key}, $key) . '"';
		} else {
			$key_str = color($COLORS->{hash_key}, $key);
		}

		# Align the hash keys
		if ($column_mode) {
			my $raw_len     = length($key);
			my $append_cnt  = $max_length - $raw_len;

			# Sometimes this goes negative?
			if ($append_cnt < 0) {
				$append_cnt = 0;
			}

			$key_str .= " " x $append_cnt;
		}

		push(@items, $key_str . ' => ' . __dump($val));
	}

	# If we're too wide for the screen we drop to column mode
	if ($column_mode) {
		$ret = "{\n";

		foreach my $x (@items) {
			my $pad = " " x ($current_indent_level * $indent_spaces);
			$ret .= $pad . "$x,\n";
		}

		my $pad = " " x (($current_indent_level - 1) * $indent_spaces);
		$ret .= $pad . "}";
	} else {
		$ret = '{ ' . join(", ", @items) . ' }';
	}

	$current_indent_level--;

	return $ret;
}

sub max_length {
	my $max = 0;

	foreach my $item (@_) {
		my $len = length($item);
		if ($len > $max) {
			$max = $len;
		}
	}

	return $max;
}

sub array_str_len {
	my @arr = @_;

	my $len = 0;
	foreach my $x (@arr) {
		if (!defined($x)) {
			$len += 5; # The string "undef"
		} elsif (ref $x eq 'ARRAY') {
			$len += array_str_len(@$x);
		} elsif (ref $x eq 'HASH') {
			$len += array_str_len(%$x);
		} else {
			$len += length($x);
			$len += 2; # For the quotes around the string
		}
	}

	return $len;
}

sub needs_column_mode {
	my $x = shift();

	my $ret  = 0;
	my $len  = 0;
	my $type = ref($x);

	if ($type eq "ARRAY") {
		my $cnt = scalar(@$x);

		$len += array_str_len(@$x);
		$len += 2;        # For the '[' on the start/end
		$len += 2 * $cnt; # ', ' for each item
	} elsif ($type eq "HASH") {
		my @keys = keys(%$x);
		my @vals = values(%$x);
		my $cnt  = scalar(@keys);

		$len += array_str_len(@keys);
		$len += array_str_len(@vals);
		$len += 4;        # For the '{ ' on the start/end
		$len += 6 * $cnt; # ' => ' and the ', ' for each item
	# This is a class/obj
	} elsif ($type) {
		my $cnt = scalar(@$x);

		$len += array_str_len(@$x);
		$len += 2;        # For the '[' on the start/end
		$len += 2 * $cnt; # ' => ' and the ', ' for each item
	}

	# If we're too wide for the screen we drop to column mode
	if ($len > $WIDTH) {
		$ret = 1;
	}

	#$ret = 1;
	#k($x);
	#k("$len => $ret");

	return $ret;
}

sub is_printable {
	my ($str) = @_;

	my $ret = 0;
	if (defined($str) && $str =~ /^[[:print:]\n\r\t]*$/) {
		$ret = 1;
	}

	return $ret;
}

################################################################################
################################################################################

sub is_undef {
	my $x = shift();

	if (!defined($x)) {
		return 1;
	} else {
		return 0;
	}
}

# Veriyf this
sub is_nan {
	my $x   = shift();
	my $ret = 0;

	if ($x != $x) {
		$ret = 1;
	}

	return $ret;
}

# Veriyf this
sub is_infinity {
	my $x   = shift();
	my $ret = 0;

	if ($x * 2 == $x) {
		$ret = 1;
	}

	return $ret;
}

sub is_string {
    my ($value) = @_;
    return defined($value) && $value !~ /^-?\d+(?:\.\d+)?$/;
}

sub is_integer {
    my ($value) = @_;
    return defined($value) && $value =~ /^-?\d+$/;
}

sub is_float {
    my ($value) = @_;
    #my $ret     = defined($value) && $value =~ /^-?\d+\.\d+$/;
    my $ret     = defined($value) && $value =~ /^-?\d+\.\d+(e[+-]\d+)?$/;

	return $ret;
}

# Borrowed from builtin::compat
sub is_bool_val {
	my $value = shift;

	# Make sure the variable is defined, is not a reference and is a dualval
	if (!defined($value))              { return 0; }
	if (length(ref($value)) != 0)      { return 0; }
	if (!Scalar::Util::isdual($value)) { return 0; }

	# Make sure the string and integer versions match
	if ($value == 1 && $value eq '1')  { return 1; }
	if ($value == 0 && $value eq '')   { return 1; }

	return 0;
}

################################################################################

sub trim {
	my ($s) = (@_, $_); # Passed in var, or default to $_
	if (!defined($s) || length($s) == 0) { return ""; }
	$s =~ s/^\s*//;
	$s =~ s/\s*$//;

	return $s;
}

# String format: '115', '165_bold', '10_on_140', 'reset', 'on_173', 'red', 'white_on_blue'
sub color {
    my ($str, $txt) = @_;

    # If we're NOT connected to a an interactive terminal don't do color
    if (-t STDOUT == 0) { return $txt || ""; }

    # No string sent in, so we just reset
    if (!length($str) || $str eq 'reset') { return "\e[0m"; }

    # Some predefined colors
    my %color_map = qw(red 160 blue 27 green 34 yellow 226 orange 214 purple 93 white 15 black 0);
    $str =~ s|([A-Za-z]+)|$color_map{$1} // $1|eg;

    # Get foreground/background and any commands
    my ($fc,$cmd) = $str =~ /^(\d{1,3})?_?(\w+)?$/g;
    my ($bc)      = $str =~ /on_(\d{1,3})$/g;

    if (defined($fc) && int($fc) > 255) { $fc = undef; } # above 255 is invalid

    # Some predefined commands
    my %cmd_map = qw(bold 1 italic 3 underline 4 blink 5 inverse 7);
    my $cmd_num = $cmd_map{$cmd // 0};

    my $ret = '';
    if ($cmd_num)      { $ret .= "\e[${cmd_num}m"; }
    if (defined($fc))  { $ret .= "\e[38;5;${fc}m"; }
    if (defined($bc))  { $ret .= "\e[48;5;${bc}m"; }
    if (defined($txt)) { $ret .= $txt . "\e[0m";   }

    return $ret;
}

sub file_get_contents {
	open(my $fh, "<", $_[0]) or return undef;
	binmode($fh, ":encoding(UTF-8)");

	my $array_mode = ($_[1]) || (!defined($_[1]) && wantarray);

	if ($array_mode) { # Line mode
		my @lines  = readline($fh);

		# Right trim all lines
		foreach my $line (@lines) { $line =~ s/[\r\n]+$//; }

		return @lines;
	} else { # String mode
		local $/       = undef; # Input rec separator (slurp)
		return my $ret = readline($fh);
	}
}

sub file_put_contents {
	my ($file, $data) = @_;

	open(my $fh, ">", $file) or return undef;
	binmode($fh, ":encoding(UTF-8)");
	print $fh $data;
	close($fh);

	return length($data);
}

sub get_terminal_width {
	my $tput = `tput cols`;

	my $width = 0;
	if ($tput) {
		$width = int($tput);
	} else {
		print color('orange', "Warning:") . " `tput cols` did not return numeric input\n";
		$width = 80;
	}

	return $width;
}

# Return bool if a function exists. Example: has_function("builtin::is_bool")
sub has_function {
	my $func_name = shift();
	my $ret       = int(exists &$func_name);

	return $ret;
}

# Creates methods k() and kd() to print, and print & die respectively
BEGIN {
	if (eval { require Data::Dump::Color }) {
		*k = sub { Data::Dump::Color::dd(@_) };
	} else {
		require Data::Dumper;
		*k = sub { print Data::Dumper::Dumper(\@_) };
	}

	sub kd {
		k(@_);

		printf("Died at %2\$s line #%3\$s\n",caller());
		exit(15);
	}
}

1;

# vim: tabstop=4 shiftwidth=4 noexpandtab autoindent softtabstop=4
