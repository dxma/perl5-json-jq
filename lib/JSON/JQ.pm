package JSON::JQ;
use strict;
use warnings;
use Carp;

our $VERSION = '0.01';
# internal flags
our $DEBUG       = 0;
our $DUMP_DISASM = 0;

use FindBin ();
FindBin::again();
use Cwd qw/abs_path/;
use File::Basename qw/dirname/;
use POSIX qw/isatty/;
# required by XS code
use JSON qw/from_json/;

# jv_print_flags in jv.h
use enum qw/BITMASK:JV_PRINT_ PRETTY ASCII COLOR SORTED INVALID REFCOUNT TAB ISATTY SPACE0 SPACE1 SPACE2/;
# jq.h
use enum qw/:JQ_DEBUG_=1 TRACE TRACE_DETAIL TRACE_ALL/;

use XSLoader;
XSLoader::load('JSON::JQ', $VERSION);

sub new {
    my ( $pkg, $param ) = @_;

    croak "script or script_file parameter required" unless exists $param->{script} or exists $param->{script_file};
    my $self = {};
    # script string or script file
    $self->{script} = $param->{script} if exists $param->{script};
    $self->{script_file} = $param->{script_file} if exists $param->{script_file};
    # script initial arguments
    $self->{variable} = exists $param->{variable} ? $param->{variable} : {};
    # internal attributes
    $self->{_attribute}->{JQ_ORIGIN} = abs_path($FindBin::Bin) if $FindBin::Bin and -d $FindBin::Bin;
    $self->{_attribute}->{JQ_LIBRARY_PATH} = exists $param->{library_paths} ? $param->{library_paths} :
        [ '~/.jq', '$ORIGIN/../lib/jq', '$ORIGIN/lib' ];
    $self->{_attribute}->{PROGRAM_ORIGIN} = abs_path(exists $param->{script_file} ? dirname($param->{script_file}) : '.');
    # error callback will push error messages into this array
    $self->{_errors} = [];
    # debug callback print flags
    my $dump_opts = JV_PRINT_INDENT_FLAGS(2);
    $dump_opts |= JV_PRINT_SORTED;
    $dump_opts |= JV_PRINT_COLOR | JV_PRINT_ISATTY if isatty(*STDERR);
    $self->{_dumpopts} = $dump_opts;
    # jq debug flags
    $self->{jq_flags} = exists $param->{debug_flag} ? $param->{debug_flag} : 0;
    bless $self, $pkg;
    unless ($self->_init()) {
        croak "jq_compile_args() failed with errors:\n  ". join("\n  ", @{ $self->{_errors} });
    }
    return $self;
}

sub process {
    my ( $self, $input ) = @_;
    my $output = [];
    if (ref $input eq 'ARRAY' or ref $input eq 'HASH') {
        # NOOP
    }
    elsif (ref $input eq 'SCALAR') {
        $input = $$input;
    }
    else {
        # json string
        $input = from_json($input);
    }
    my $rc = $self->_process($input, $output);
    # treat it as option EXIT_STATUS is on
    $rc -= 10 if $rc >= 10;
    unless ($rc == 0) {
        croak "process() failed with errors:\n  ". join("\n  ", @{ $self->{_errors} });
    }
    return wantarray ? @$output : $output;
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
