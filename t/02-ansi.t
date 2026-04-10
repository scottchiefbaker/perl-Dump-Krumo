#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 2;

################################################################################

# ANSI highlight tests
is(Dump::Krumo::bleach_text(kx("\e[1;32m")), '(\e[1;32m)'    , "ANSI color #1");
is(Dump::Krumo::bleach_text(kx("\e[32foo")), '"\e[32foo"'    , "ANSI color #2 missing closing delim");
is(Dump::Krumo::bleach_text(kx("\e[0mbar")), '(\e[0m)\'bar\'', "ANSI reset with text");

my $str1 = Dump::Krumo::color(123, 'hello');
my $str2 = Dump::Krumo::color(77) . 'hello';

is(Dump::Krumo::bleach_text(kx($str1)), '(\e[38;5;123m)\'hello\'(\e[0m)', "8bit Colorized word");
is(Dump::Krumo::bleach_text(kx($str2)), '(\e[38;5;77m)\'hello\''        , "8bit Colorized word no end close");

done_testing();
