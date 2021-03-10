# -*- perl -*-
use Test::More tests => 6;

use blib;
use FindBin;

BEGIN { use_ok( 'JSON::JQ' ); }
can_ok('JSON::JQ', qw/new _init/);

my $jq1 = JSON::JQ->new({ script => '.' });
isa_ok($jq1, 'JSON::JQ');

my $jq2 = JSON::JQ->new({ script => '.', variable => { foo => 'bar' } });
isa_ok($jq2, 'JSON::JQ');

my $jq3 = JSON::JQ->new({ script => '.', library_paths => [ "$FindBin::Bin/../jq" ] });
isa_ok($jq3, 'JSON::JQ');

eval { my $jq4 = JSON::JQ->new({ script => '. ||' }) };
my $error = $@;
like($error, qr/jq_compile_args\(\) failed with errors/);