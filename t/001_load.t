# -*- perl -*-

# t/001_load.t - check module loading and create testing directory

use Test::More tests => 2;

BEGIN { use_ok( 'JSON::JQ' ); }

my $object = JSON::JQ->new ();
isa_ok ($object, 'JSON::JQ');


