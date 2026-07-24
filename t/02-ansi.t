#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 2;

my @x = ();

################################################################################

# ANSI highlight tests
is(Dump::Krumo::bleach_text(kx("\e[1;32m")), '(\e[1;32m)'    , "ANSI color #1");
is(Dump::Krumo::bleach_text(kx("\e[32foo")), '"\e[32foo"'    , "ANSI color #2 missing closing delim");
is(Dump::Krumo::bleach_text(kx("\e[0mbar")), '(\e[0m)\'bar\'', "ANSI reset with text");

my $str1 = Dump::Krumo::color(123, 'hello');
my $str2 = Dump::Krumo::color(77) . 'hello';

is(Dump::Krumo::bleach_text(kx($str1)), '(\e[38;5;123m)\'hello\'(\e[0m)', "8bit Colorized word");
is(Dump::Krumo::bleach_text(kx($str2)), '(\e[38;5;77m)\'hello\''        , "8bit Colorized word no end close");

# Empty array/hash with color - verify empty_braces coloring and no corrupted ANSI
is(Dump::Krumo::bleach_text(kx())     , '()', "Empty array () has no stray ANSI");
is(Dump::Krumo::bleach_text(kx([]))   , '[]', "Empty arrayref [] has no stray ANSI");
is(Dump::Krumo::bleach_text(kx({}))   , '{}', "Empty hashref {} has no stray ANSI");

# Verify the raw output contains proper empty_braces ANSI wrapping
my $empty_arr = kx();
is($empty_arr, "\e[1m\e[38;5;15m()\e[0m", "Empty () wrapped in empty_braces color");

my $empty_ref = kx([]);
is($empty_ref, "\e[1m\e[38;5;15m[]\e[0m", "Empty [] wrapped in empty_braces color");

done_testing();
