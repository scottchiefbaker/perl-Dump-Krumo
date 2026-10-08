#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;
$Dump::Krumo::use_color     = 2;
$Dump::Krumo::WIDTH         = 100; # Not the terminal width, so tests are reproducible anywhere

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

################################################################################
# color()
################################################################################

# Foreground 256 colors, with and without a command
is(Dump::Krumo::color(123, "hello"), "\e[38;5;123mhello\e[0m", "color() plain 8bit");
is(Dump::Krumo::color("15_bold"),     "\e[1m\e[38;5;15m",       "color() bold + 8bit");
is(Dump::Krumo::color("bold", "x"),   "\e[1mx\e[0m",             "color() command only");

# Named colors
is(Dump::Krumo::color("red", "x"),   "\e[38;5;160mx\e[0m", "color() red");
is(Dump::Krumo::color("green", "x"), "\e[38;5;34mx\e[0m",  "color() green");
is(Dump::Krumo::color("white", "x"), "\e[38;5;15mx\e[0m",  "color() white");

# Background colors
is(Dump::Krumo::color("on_173", "x"),        "\e[48;5;173mx\e[0m",          "color() background only");
is(Dump::Krumo::color("white_on_blue", "x"), "\e[38;5;15m\e[48;5;27mx\e[0m", "color() fg + bg");

# Reset handling
is(Dump::Krumo::color("reset"), "\e[0m", "color() reset");
is(Dump::Krumo::color(""),      "\e[0m", "color() empty string is a reset");
is(Dump::Krumo::color("", "x"), "\e[0m", "color() empty string drops the text");

# Invalid colors are ignored
is(Dump::Krumo::color(300, "x"), "x\e[0m", "color() above 255 is invalid");
is(Dump::Krumo::color("nope"),  "",        "color() unknown name has no fg");

# Only the first three digits of a number are used
is(Dump::Krumo::color(12345, "x"), "\e[38;5;123mx\e[0m", "color() longer numbers are truncated");

################################################################################
# bleach_text()
################################################################################

is(Dump::Krumo::bleach_text("\e[0m\e[38;5;1m\e[48;5;2mtext\e[0m"), "text", "bleach_text() strips all codes");
is(Dump::Krumo::bleach_text("\e[1;4;32mtext\e[0m"),   "text", "bleach_text() strips multi code sequences");
is(Dump::Krumo::bleach_text("no codes here"),         "no codes here", "bleach_text() leaves plain text alone");

# The colored word we get back from color() bleaches back to the original
is(Dump::Krumo::bleach_text(Dump::Krumo::color(77, "hello")), "hello", "bleach_text() undoes color()");

################################################################################
# quote_string()
################################################################################

is(Dump::Krumo::quote_string("foobar"),       "'foobar'",     "quote_string() plain single quotes");
is(Dump::Krumo::quote_string("it's"),         '"it\'s"',      "quote_string() single quote in the value");
is(Dump::Krumo::quote_string('a"b'),          '\'a"b\'',      "quote_string() double quote in the value");
is(Dump::Krumo::quote_string('a"b\'c'),       '"a\\"b\'c"',   "quote_string() both quotes in the value");
is(Dump::Krumo::quote_string("a\ta"),         '"a\ta"',      "quote_string() tab");
is(Dump::Krumo::quote_string("a\nb"),         '"a\nb"',      "quote_string() newline");
is(Dump::Krumo::quote_string('a\\b'),         '"a\\\\b"',    "quote_string() backslash");
is(Dump::Krumo::quote_string('$x@y'),         '"\\$x\\@y"',  "quote_string() sigils are escaped");

################################################################################
# colorize_ansi()
################################################################################

my $colored_ansi = Dump::Krumo::colorize_ansi("\e[1;32m");
is(Dump::Krumo::bleach_text($colored_ansi), '(\e[1;32m)', "colorize_ansi() bleaches to the visible form");

# A string that does not start with an escape is returned unchanged
is(Dump::Krumo::colorize_ansi("hello"), "hello", "colorize_ansi() passes plain text through");

done_testing();
