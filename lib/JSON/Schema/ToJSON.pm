package JSON::Schema::ToJSON;

use strict;
use warnings;

use Cpanel::JSON::XS;
use JSON::Validator;

use Exporter 'import';
our @EXPORT  = 'json_schema_to_json';
our $VERSION = '0.01_01';

sub new { bless( {},$_[0] ) }

sub json_schema_to_json {
	my ( $self,%args ) = @_;

	my $schema = $args{schema}; # an already parsed JSON schema

	if ( ! $schema ) {
		$schema = $args{schema_str} # an uparsed JSON schema
			|| die "json_schema_to_json needs schema or schema_str arg";

		eval { $schema = decode_json( $schema ); }
		or do { die "json_schema_to_json failed to parse schema: $@" };
	}

	my $schema_type = JSON::Validator::_guess_schema_type( $schema );
	my $method      = "_random_$schema_type";

	return $self->$method( $schema );
}

sub _random_boolean {
	my ( $self,$schema ) = @_;

	return rand > 0.5
		? Cpanel::JSON::XS::true
		: Cpanel::JSON::XS::false
}

sub _random_integer {
	my ( $self,$schema ) = @_;

	my $min = $schema->{minimum};
	my $max = $schema->{maximum};
	my $mof = $schema->{multipleOf};

	# by default the min/max values are exclusive
	$min++ if defined $min && $schema->{exclusiveMinimum};
	$max-- if defined $max && $schema->{exclusiveMaximum};

	my @possible_values = defined $min && defined $max
		? $min .. $max
		: defined $min
			? $min .. $min + ( $min * $min )
			: defined $max
				? ( $max * $max ) .. $max 
				: 0 .. 2147483647;

	# if we have multipleOf just return the first value that fits. note that
	# there is a possible bug here and the JSON schema spec isn't clear about
	# it - it's possible to have a multipleOf that would never be possible
	# given certain minimum and maximum
	if ( $mof ) {

	} else {
		return $possible_values[ int( rand( $#possible_values ) ) ];
	}
}

=encoding utf8

=head1 NAME

JSON::Schema::ToJSON - Generate example JSON structures from JSON Schema definitions

=head1 VERSION

0.01_01

=head1 SYNOPSIS

  use JSON::Schema::ToJSON;

  my $to_json  = JSON::Schema::ToJSON->new;

  my $perl_string_hash_or_arrayref = $to_json->json_schema_to_json(
    schema     => $already_parsed_json_schema,  # either this
    schema_str => '{ "type" : "boolean" }',     # or this
  );

=head1 DESCRIPTION

L<JSON::Schema::ToJSON> is a class for generating "fake" or "example" JSON data
structures from JSON Schema structures.

Note this distribution is currently B<EXPERIMENTAL> and subject to breaking changes.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/json-schema-tojson

=head1 AUTHOR

Lee Johnson - C<leejo@cpan.org>

=cut

1;

# vim:noet:sw=4:ts=4
