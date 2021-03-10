package JSON::JQ;
use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

use FindBin ();
# required by XS code
use JSON ();

use XSLoader;
XSLoader::load('JSON::JQ', $VERSION);

sub new {
    my ( $pkg, $param ) = @_;

    croak "script parameter required" unless exists $param->{script};
    my $self = {};
    $self->{script} = $param->{script};
    $self->{variable} = exists $param->{variable} ? $param->{variable} : {};
    $self->{_attribute}->{JQ_ORIGIN} = $FindBin::Bin;
    $self->{_attribute}->{JQ_LIBRARY_PATH} = exists $param->{library_paths} ? $param->{library_paths} : [ '~/.jq', '$ORIGIN/../lib/jq', '$ORIGIN/lib' ];
    $self->{_errors} = [];
    bless $self, $pkg;
    unless ($self->_init()) {
        croak "jq_compile_args() failed with errors:\n  ". join("\n  ", @{ $self->{_errors} });
    }
    return $self;
}

sub process {
    my ( $self, $data ) = @_;
}

=head1 NAME

JSON::JQ - jq (https://stedolan.github.io/jq/) library binding

=head1 SYNOPSIS

  use JSON::JQ;
  blah blah blah


=head1 DESCRIPTION

Blah blah blah.


=head1 USAGE



=head1 BUGS

Please report bug to https://github.com/dxma/perl5-json-jq/issues

=head1 AUTHOR

    Dongxu Ma
    CPAN ID: DONGXU
    dongxu _dot_ ma _at_ gmail.com
    https://github.com/dxma

=head1 COPYRIGHT

This program is free software licensed under the...

	The MIT License

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

https://github.com/stedolan/jq/wiki

=cut

1;
