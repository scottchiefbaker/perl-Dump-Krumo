#!perl
use 5.006;
use strict;
use warnings;
use Test::More;
use Dump::Krumo;

$Dump::Krumo::return_string = 1;

is(kx([1,2,3]), '[1, 2, 3]');
is(kx([!!1])  , '[true]');

done_testing();
