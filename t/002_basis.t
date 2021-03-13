# -*- perl -*-
#use Test::More tests => 1;

use blib;
use FindBin;

use JSON::JQ;
use JSON qw/to_json/;

my $jq1 = JSON::JQ->new({ script => '.' });
print to_json($jq1->process({ foo => 'bar' })), "\n";