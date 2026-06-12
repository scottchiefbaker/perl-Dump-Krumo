#!/usr/bin/env perl

use strict;
use warnings;
use v5.16;
use Scalar::Util;

package Dump::Krumo;

use Carp;
use Exporter 'import';

our @EXPORT    = qw(kx kxd);
our @EXPORT_OK = qw(k kd);

# If you `use Dump::Krumo (":short");` then you get k() and kd() instead
our %EXPORT_TAGS = ('short' => [('k', 'kd')]);

# https://blogs.perl.org/users/grinnz/2018/04/a-guide-to-versions-in-perl.html
our $VERSION = 'v0.1.9';

our $use_color      = 1; # Output in color
our $return_string  = 0; # Return a string instead of printing it
our $hash_sort      = 1; # Sort hash keys before output
our $debug          = 0; # Low level developer level debugging
our $disable        = 0; # Disable Dump::Krumo
our $indent_spaces  = 2; # Number of spaces to use for each level of indent
our $promote_bool   = 1; # Convert JSON::PP::Boolean to raw true/false
our $stack_trace    = 0; # kxd() prints a stack trace
our $short_hex      = 0; # Output \x12 instead of \x{12}
our $highlight_ansi = 1;

# Regexp to match an ANSI escape sequence
my $ansi_regex = qr/(\e\[(?:[0-9]{0,3}(?:;[0-9]{1,3}){0,10})[mK])/;

# Global var to track how many levels we're indented
my $current_indent_level = 0;
# Global var to track the indent to the right end of the most recent hash key
my $left_pad_width       = 0;
# Global var to track extra content width from structural prefixes (e.g.
# the '"ClassName" :: ' prepended by __dump_class).  Added to the total
# in needs_column_mode() alongside left_pad_width.
my $content_offset       = 0;

our $COLORS = {
	'string'        => 230,            # Standard strings
	'control_char'  => 226,            # the `\n`, `\r`, and `\t` inside strings
	'undef'         => 196,            # undef
	'hash_key'      => 208,            # hash keys on the left of =>
	'integer'       => 33,             # integers
	'float'         => 51,             # things that look like floating point
	'class'         => 118,            # Classes/Object names
	'binary'        => 226,            # \x{12} inside of strings
	'scalar_ref'    => 225,            # References to scalar variables
	'boolean_false' => 'white_on_124', # Native boolean false
	'boolean_true'  => 'white_on_22',  # Native boolean true
	'regexp'        => 164,            # qr() style regexp variables
	'glob'          => 40,             # \*STDOUT variables
	'coderef'       => 168,            # code references
	'vstring'       => 153,            # Version strings
	'empty_braces'  => '15_bold',      # Either [] or {} or ''
};

# `\n`, `\r`, and `\t` get highlighted to these values
my $ctrl_color = color(get_color('control_char'));
my $str_color  = color(get_color('string'));
my $slash_n    = $ctrl_color . '\\n' . $str_color;
my $slash_r    = $ctrl_color . '\\r' . $str_color;
my $slash_t    = $ctrl_color . '\\t' . $str_color;

# WIDTH is the terminal column width used to decide if data fits on one line
# or must wrap to column mode. Detected via `tput cols`, falling back to 100.
our $WIDTH = get_terminal_width();
$WIDTH  ||= 100;

###############################################################################
###############################################################################

# Dump the variable information
sub kx {
	my @arr = @_;

	# If we are globally disabled we do nothing
	if ($disable) { return -1; }

	my @items    = ();
	my $cnt      = scalar(@arr);
	my $is_array = 0;

	# If someone passes in a real array (not ref) we fake it out
	if ($cnt > 1 || $cnt == 0) {
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
		my $len = length($str);
		$str    = substr($str, 1, $len - 2);
	}

	if ($cnt > 1 || $cnt == 0) {
		$str = "($str)";
	}

	if ($return_string) {
		return $str;
	} else {
		print color('reset'); # Clear any shell ANSI colors
		print "$str\n";
	}
}

# Dump the variable and die and output file/line
sub kxd {
	# If we are globally disabled we do nothing
	if ($disable) { return -1; }

	kx(@_);

	print "\n";

	my $str = color('117', "Dump::Krumo") . " died";

	if ($stack_trace) {
		confess($str);
	} else {
		croak($str);
	}
}

# Generic dump that handles each type appropriately
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
		$ret = color(get_color('scalar_ref'), '\\' . quote_string($$x));
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
	} elsif ($type eq "CODE") {
		$ret = __dump_coderef($class, $x);
	} elsif ($type eq "VSTRING") {
		$ret = __dump_vstring($x);
	} elsif ($class) {
		$ret = __dump_class($class, $x);
	} else {
		$ret = "Unknown variable type: '$type'";
	}

	return $ret;
}

################################################################################
# Each variable type gets it's own dump function
################################################################################

sub __dump_bool {
	my $x = shift();
	my $ret;

	if ($x) {
		$ret = color(get_color('boolean_true'), "true");
	} else {
		$ret = color(get_color('boolean_false'), "false");
	}

	return $ret;
}

sub __dump_regexp {
	my ($class, $x) = @_;

	my $ret = color(get_color('regexp'), "qr$x");

	return $ret;
}

sub __dump_coderef {
	my ($class, $x) = @_;

	my $ret = color(get_color('coderef'), "sub { ... }");

	return $ret;
}

sub __dump_glob {
	my ($class, $x) = @_;

	my $ret = color(get_color('glob'), "\\" . $$x);

	return $ret;
}

sub __dump_class {
	my ($class, $x) = @_;

	my $ret      = '"' . color(get_color('class'), $class) . "\" :: ";
	my $reftype  = Scalar::Util::reftype($x);
	my $y;

	if ($promote_bool && $class eq 'JSON::PP::Boolean') {
		my $val = $$x;
		return __dump_bool(!!$val);
	}

	my $len = length($class) + 6; # 2x quotes and ' :: '
	$content_offset += $len;

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

	$content_offset -= $len;

	return $ret;
}

sub __dump_integer {
	my $x   = shift();
	my $ret = color(get_color('integer'), $x + 0);

	return $ret;
}

sub __dump_float {
	my $x   = shift();
	my $ret = color(get_color('float'), $x + 0);

	return $ret;
}

sub __dump_vstring {
	my $x   = shift();

	my @parts = unpack("C*", $$x);
	my $str   = "\\v" .(join ".", @parts);

	my $ret = color(get_color('vstring'), $str);

	return $ret;
}

sub __dump_string {
	my $x = shift();

	# This is the catch all for "" or ''
	if (length($x) == 0) {
		return color(get_color('empty_braces'), "''"),
	}

	# Highlight internal ANSI color sequences in a string
	if ($highlight_ansi && $x =~ $ansi_regex) {
		return highlight_ansi($x);
	}

	# Is the whole string printable
	my $printable = is_printable($x);

	# https://blogs.perl.org/users/mauke/2026/04/quick-and-dirty-string-dumping.html
	#printf("%vd (len = %d) (print = %d)\n", $x, length($x), $printable);

	my $ret = '';

	# For short strings we show the unprintable chars as \x{00} escapes
	if (!$printable) {
		my @p = unpack("C*", $x);

		my $str  = '';
		my $unpr = 0; # Count of unprintable chars
		foreach my $x (@p) {
			my $is_printable = is_printable(chr($x));

			if ($is_printable) {
				$str .= color(get_color('string'),chr($x));
			} elsif ($x == 27) { # \e
				$str .= color(get_color('binary'), '\\e');
			} elsif ($x == 10) { # \n
				$str .= color(get_color('binary'), '\\n');
			} elsif ($x == 9) {  # \t
				$str .= color(get_color('binary'), '\\t');
			} elsif ($x == 13) { # \r
				$str .= color(get_color('binary'), '\\r');
			} else {
				if ($short_hex) {
					$str .= color(get_color('binary'), '\\x' . sprintf("%02X", $x));
				} else {
					$str .= color(get_color('binary'), '\\x{' . sprintf("%02X", $x) . '}');
				}
			}

			if (!$is_printable) {
				$unpr++;
			}
		}

		# Calculate the percentage of unpritable chars
		my $total = scalar(@p);
		my $per   = ($unpr / $total) * 100;

		#printf("Len = %d / Unprintable = %0.2f%%\n", $total, $per);

		# For longer strings that are MOSTLY unprintable we output a pack statement
		if ($total > 20 && $per > 30) {
			$ret = color(get_color('binary'), 'pack(\'H*\', \'' . bin2hex($x) . '\')');
		# Output the string with non-printable chars highlighted
		} else {
			$ret = "\"$str\"";
		}
	} else {
		my $quoted = quote_string($x);
		$ret       = color(get_color('string'), $quoted);
	}

	$ret =~ s/\n/$slash_n/g;
	$ret =~ s/\r/$slash_r/g;
	$ret =~ s/\t/$slash_t/g;

	return $ret;
}

sub __dump_undef {
	my $ret = color(get_color('undef'), 'undef');

	return $ret;
}

sub __dump_array {
	my $x = shift();

	$current_indent_level++;

	# Catch if it's an empty array
	my $cnt = scalar(@$x);
	if ($cnt == 0) {
		$current_indent_level--;
		return color(get_color('empty_braces'), '[]'),
	}

	# See if we need to switch to column mode to output this array
	my $column_mode = needs_column_mode($x);

	# Loop through each item and dump it approprirately
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
	my @keys  = keys(%$x);
	my @vals  = values(%$x);
	my $cnt   = scalar(@keys);

	# Catch an empty hash like: {}
	if ($cnt == 0) {
		$current_indent_level--;
		return color(get_color('empty_braces'), '{}'),
	}

	# There may be some weird scenario where we do NOT want to sort
	if ($hash_sort) {
		@keys = sort(@keys);
	}

	# Calculate the column mode decision and key-alignment width.
	#
	# max_length      — longest hash key, used to pad shorter keys so
	#                   '=>' operators line up vertically in column mode.
	# saved_pad_width — snapshot of left_pad_width before we override it
	#                   for the duration of this hash's rendering.
	# column_mode     — true if the inline representation would exceed
	#                   the terminal width.
	#
	# During needs_column_mode(), left_pad_width is still the value from
	# the parent scope (e.g. a class label or an enclosing hash key).
	# After the check we set it to max_length so that child dumps
	# (values of this hash) can account for this hash's key width when
	# they themselves are tested via needs_column_mode().
	my $max_length      = max_length(@keys);
	my $saved_pad_width = $left_pad_width;
	$left_pad_width     = $saved_pad_width;
	my $column_mode     = needs_column_mode($x);
	$left_pad_width     = $max_length;

	# If we're not in column mode there is no need to compensate for this
	if (!$column_mode) {
		$max_length = 0;
	}

	# Check to see if any of the array keys need to be quoted
	my $keys_need_quotes = 0;
	foreach my $key (@keys) {
		if ($key =~ /\W/) {
			$keys_need_quotes = 1;
			last;
		}
	}

	# Loop through each key and build the appropriate string for it
	foreach my $key (@keys) {
		my $val = $x->{$key};

		my $key_str = '';
		if ($keys_need_quotes) {
			$key_str = "'" . color(get_color('hash_key'), $key) . "'";
		} else {
			$key_str = color(get_color('hash_key'), $key);
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
	$left_pad_width = $saved_pad_width;

	return $ret;
}

################################################################################
# Various helper functions
################################################################################

# Calculate the length of the longest string in a list of strings.
# Used to determine how much padding to add after hash keys so
# the '=>' operators align vertically in column mode.
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

# Estimate the rendered string length of a list of items, counting
# how many characters the inline (non-column) representation would
# occupy. This is deliberately conservative (no ANSI codes) because
# we only need a rough "will this fit on one line?" comparison.
#
# For scalars we count:
#   - undef             => 5 chars
#   - booleans          => "true" (4) or "false" (5)
#   - numbers           => length of the value as-is
#   - strings           => length + 2 (for surrounding quotes)
#
# For blessed objects we mirror the __dump dispatch order:
#   - Regexp            => length of stringified qr// form
#   - JSON::PP::Boolean => "true" / "false" (if promotion is on)
#   - Other classes     => "ClassName" :: <content-length>
#
# where <content-length> recurses into the underlying reftype
# (ARRAY, HASH, SCALAR, or fallback stringification).
#
# Nested ARRAY/HASH refs recurse.  Once the running total exceeds
# WIDTH we short-circuit with a large sentinel value to avoid
# wasting CPU on deeply nested structures that will obviously
# require column mode anyway.
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
		} elsif (is_bool_val($x) && $x) {
			$len += 4; # "true" is 4 chars
		} elsif (is_bool_val($x)) {
			$len += 5; # "false" is 5 chars
		} elsif (my $class = Scalar::Util::blessed($x)) {
			# Blessed object — estimate the rendered width to match
			# the __dump dispatch order (__dump_regexp first, then
			# JSON::PP::Boolean promotion, then __dump_class).
			if ($class eq 'Regexp') {
				$len += length("$x");  # qr/.../
			} elsif ($promote_bool && $class eq 'JSON::PP::Boolean') {
				$len += ($$x) ? 4 : 5;  # true / false
			} else {
				# "ClassName" :: content — matches __dump_class()
				$len += length($class) + 6;
				my $reftype = Scalar::Util::reftype($x);
				if ($reftype eq 'ARRAY') {
					$len += array_str_len(@$x);
				} elsif ($reftype eq 'HASH') {
					$len += array_str_len(%$x);
				} elsif ($reftype eq 'SCALAR') {
					$len += length($$x);   # epoch number, string, etc.
				} else {
					$len += length("$x");
				}
			}
		} else {
			$len += length($x);

			if (!is_numeric($x)) {
				$len += 2; # For the quotes around the string
			}
		}

		# We stop counting after we hit $WIDTH so we don't
		# waste a bunch of CPU cycles counting something we
		# won't ever use (useful in big nested objects)
		if ($len > $WIDTH) {
			return $WIDTH + 999;
		}
	}

	return $len;
}

# Decide whether a data structure is too wide to render inline and must
# use column mode (one key/value per line).  We estimate the full rendered
# width as:
#
#   total = left_indent + hash_padding + content_length
#
# where:
#   left_indent   = current nesting depth (in spaces)
#   hash_padding  = width of the longest hash key seen so far + 4 for ' => '
#   content_length = estimated string length of all values + separators
#
# If total > 97% of terminal width, we switch to column mode.  The 97%
# fudge factor acknowledges that our length estimation is approximate
# (ANSI codes are stripped, nested structures are recursed, etc.).
sub needs_column_mode {
	my ($x) = @_;

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
		$len += 6 * $cnt; # ' => ' (4) + the ', ' separator (2) for each pair
	# Blessed object — use reftype for accurate width estimation.
	# This branch is a safety net: in normal flow, __dump_class
	# creates an unblessed copy so the ARRAY/HASH branches above
	# handle the content.  The class prefix width is tracked via
	# $content_offset, set by __dump_class.
	} elsif ($type) {
		my $reftype = Scalar::Util::reftype($x);

		if ($reftype eq 'HASH') {
			my @keys = keys(%$x);
			my @vals = values(%$x);
			my $cnt  = scalar(@keys);

			$len += array_str_len(@keys);
			$len += array_str_len(@vals);
			$len += 4;        # '{ ' and ' }'
			$len += 6 * $cnt; # ' => ' + ', ' for each pair
		} elsif ($reftype eq 'ARRAY') {
			my $cnt = scalar(@$x);

			$len += array_str_len(@$x);
			$len += 2;        # '[' and ']'
			$len += 2 * $cnt; # ', ' for each item
		} else {
			# SCALAR, GLOB, CODE, etc. — rough estimate
			$len += length("$x");
		}
	}

	# Add any structural content offset (e.g. class prefix "ClassName" :: )
	$len += $content_offset;

	my $content_len = $len;

	# Current number of spaces we're indented from the left
	my $left_indent  = ($current_indent_level - 1) * $indent_spaces;
	# Where the ' => ' in the hash key ends
	my $pad_width    = $left_pad_width + 4; # For the ' => '

	# Add it all together
	$len = $left_indent + $pad_width + $len;

	# If we're too wide for the screen we drop to column mode
	# Our math isn't 100% down the character so we use 97% to give
	# ourselves some wiggle room
	if ($len > ($WIDTH * .97)) {
		$ret = 1;
	}

	# This math is kinda gnarly so if we turn on debug mode we can
	# see each array/hash and how we calculate the length
	if ($debug) {
		state $first = 1;

		if ($first) {
			printf("Screen width: %d\n\n", $WIDTH * .97);
			printf("Left Indent | Hash Padding | Content | Total\n");
			$first = 0;
		}

		printf("%8d    +    %6d    +  %4d  = %4d    (%d)\n", $left_indent, $pad_width, $content_len, $len, $ret);
	}

	return $ret;
}

# Convert raw bytes to hex for easier printing
sub bin2hex {
	my $bytes = shift();
	my $ret   = uc(unpack("H*", $bytes));

	return $ret;
}

################################################################################
# Test functions to determine what type of variable something is
################################################################################

# Does the string contain only printable characters
sub is_printable {
	my ($str) = @_;

	# If we're just checking a single char, anything out of the ASCII range is
	# not considered printable
	if (length($str) == 1 && (ord($str) >= 127)) {
		return 0;
	}

	my $ret = 0;
	if (defined($str) && $str =~ /^[[:print:]]*$/) {
		$ret = 1;
	}

	return $ret;
}

sub is_undef {
	my $x = shift();

	if (!defined($x)) {
		return 1;
	} else {
		return 0;
	}
}

# Verify this
sub is_nan {
	my $x   = shift();
	my $ret = 0;

	if ($x != $x) {
		$ret = 1;
	}

	return $ret;
}

# Verify this
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

	# For our purposes it's considered a string if it doesn't look like a number
	return defined($value) && !is_numeric($value);
}

sub is_integer {
	my ($value) = @_;

	return defined($value) && $value =~ /^[+-]?\d+$/;
}

sub is_float {
	my ($value) = @_;

	# Note 1.2e+100 is considered a float along with the more common types
	my $ret     = defined($value) && $value =~ /^[+-]?\d+\.\d+(e[+-]\d+)?$/;

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

sub is_numeric {
	my $ret = Scalar::Util::looks_like_number($_[0]);

	return $ret;
}

# This is a wrapper needed for :short
sub k {
	return kx(@_);
}

# This is a wrapper needed for :short
sub kd {
	return kxd(@_);
}

################################################################################

# String format: '115', '165_bold', '10_on_140', 'reset', 'on_173', 'red', 'white_on_blue'
sub color {
	my ($str, $txt) = @_;

	# If we're NOT connected to a an interactive terminal don't do color
	state $color_available = ($use_color && -t STDOUT != 0);
	# Force color on
	if ($use_color == 2) { $color_available = 1; };

	if (!$color_available) {
		return $txt // "";
	}

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

# Remove all ANSI codes from a string
sub bleach_text {
	my $str = shift();
	$str    =~ s/\e\[\d*(;\d+)*m//mg;

	return $str;
}

# Determine the terminal width in columns by shelling out to `tput cols`.
# Returns 0 if no interactive terminal is detected (caller falls back to
# the default WIDTH of 100).  The width is cached in $WIDTH at module
# load time, not re-queried per call.
sub get_terminal_width {
	# If there is no $TERM then tput will bail out
	if (!$ENV{TERM} || -t STDOUT == 0) {
		return 0;
	}

	my $tput  = `tput cols`;
	my $width = 0;

	if ($tput) {
		$width = int($tput);
	} else {
		print color('orange', "Warning:") . " `tput cols` did not return numeric input\n";
		$width = 80;
	}

	return $width;
}

# See also B::perlstring as a possible alternative
sub quote_string {
	my ($s) = @_;

	# Use single quotes if no special chars
	if ($s !~ /[\'\\\n\r\t\f\$@]/ ) {
		return "'$s'";
	}

	# Otherwise, escape for double quotes
	(my $escaped = $s) =~ s/([\\"])/\\$1/g;
	$escaped =~ s/\n/\\n/g;
	$escaped =~ s/\r/\\r/g;
	$escaped =~ s/\t/\\t/g;
	$escaped =~ s/\f/\\f/g;

	return "\"$escaped\"";
}

# This is used to look up the color for each type
sub get_color {
	my $str = $_[0] || "";

	my $ret = $COLORS->{$str} // 251;

	return $ret;
}

sub highlight_ansi {
	my $str = shift();

	# Get all the non-empty parts
	my @parts = split(/$ansi_regex/i, $str);
	@parts    = grep { $_; } @parts;

	# Loop through each part of the string colorizing the ANSI or
	# the regular string depending which is it
	my $ret = '';
	foreach my $str (@parts) {
		# No need to be more strict, because the split above checks
		# for valid ANSIness
		my $is_ansi = $str =~ m/^\e/;

		if ($is_ansi) {
			$str = colorize_ansi($str);
		} else {
			$str = __dump_string($str);
		}

		$ret .= $str;
	}

	return $ret;
}

sub colorize_ansi {
	my $str = shift();

	my $start = $str =~ s/^(\e\[)//;
	my $end   = $str =~ s/[mK]$//;

	if (!$start) {
		return $str;
	}

	# Get each ANSI number
    my @parts = split(/;/, $str);

	# Color for the numbers, and the `;` separator
    my $color = color("15_bold");
    my $sep   = color('reset') . color(146);
	my $esc   = color(51);
	my $reset = color();

	# Colorize each number
	foreach (@parts) {
		$_ = $color . $_;
	}

	my $ret = $sep . '(' . $esc . '\\e' . $sep . '[';
	for (my $i = 0; $i < @parts; $i++) {
		my $p = $parts[$i];
		my $is_last = $i == scalar(@parts) - 1;

		if (!$is_last) {
			$ret .= $p . $sep . ";";
		} else {
			$ret .= $p;
		}
	}

	$ret .= $sep . "m)";
	$ret .= $reset;

	return $ret;
}


################################################################################
################################################################################
################################################################################

=encoding utf8

=head1 NAME

Dump::Krumo - Fancy, colorful, human readable dumps of your data

=head1 SYNOPSIS

    use Dump::Krumo;

    my $data = { one => 1, two => 2, three => 3 };
    kx($data);

    my $list = ['one', 'two', 'three', 'four'];
    kxd($list);

=head1 DESCRIPTION

Colorfully dump your data to make debugging variables easier. C<Dump::Krumo>
focuses on making your data human readable and easily parseable.

=begin markdown

# SCREENSHOTS

<img width="1072" height="942" alt="image" src="https://github.com/user-attachments/assets/970932a4-21cb-4add-bf9d-f4a007435181" />

=end markdown

=head1 METHODS

=over 4

=item B<kx($var)>

Debug print C<$var>.

=item B<kxd($var)>

Debug print C<$var> and C<die()>. This outputs file and line information.

=back

=head1 OPTIONS

=over 4

=item C<$Dump::Krumo::use_color = 1>

Turn color on/off.

=over 4

=item *

Setting to C<0> disables color

=item *

Setting to C<1> enables color for interactive shells (smart detection)

=item *

Setting to C<2> forces color to be enabled

=back

=item C<$Dump::Krumo::return_string = 0>

Return a string instead of printing out

=item C<$Dump::Krumo::indent_spaces = 2>

Number of spaces to indent each level

=item C<$Dump::Krumo::disable = 0>

Disable all output from C<Dump::Krumo>. This allows you to leave all of your
debug print statements in your code, and disable them at runtime as needed.

=item C<$Dump::Krumo::promote_bool = 1>

Convert JSON::PP::Booleans to true/false instead of treating them as objects.

=item C<$Dump::Krumo::stack_trace = 0>

When C<kxd()> is called it will dump a full stack trace.

=item C<$Dump::Krumo::highlight_ansi = 1>

Colorize and make visible ANSI escape sequences

=item C<$Dump::Krumo::short_hex = 0>

Use shorter hex syntax for strings with unpritable characters. By default we
print C<\x{01}\x\{02}\x{03}>, but with short_hex enabled we print without
braces instead: C<\x01\x02\x03>.

=item C<$Dump::Krumo::COLORS>

Reference to a hash of colors for each variable type. Update this and create
your own color scheme.

=back

=head1 SEE ALSO

=over

=item *
L<Data::Dumper>

=item *
L<Data::Dump>

=item *
L<Data::Dump::Color>

=item *
L<Data::Printer>

=back

=head1 AUTHOR

Scott Baker - L<https://www.perturb.org/>

=cut

1;

# vim: tabstop=4 shiftwidth=4 noexpandtab autoindent softtabstop=4
