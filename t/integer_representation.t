# -*- perl -*-
use Test::More tests => 1;

use strict;
use warnings;

use JSON::JQ;

my $jq = JSON::JQ->new({ script => '.' });
my $input = 1651546351000;
my $expected = 1651546351000;
is(${$jq->process({ data => $input })}[0], $expected, 'integer representation');
