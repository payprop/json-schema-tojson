package JSON::Schema::ToJSON;

use strict;
use warnings;

use Cpanel::JSON::XS;
use JSON::Validator;
use String::Random;

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

	my $method = $self->_guess_method( $schema );
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
				: defined $mof
					? $mof .. $mof
					: 1 .. 1000 # short range, prevent creation of a massive array
	;

	# if we have multipleOf just return the first value that fits. note that
	# there is a possible bug here and the JSON schema spec isn't clear about
	# it - it's possible to have a multipleOf that would never be possible
	# given certain minimum and maximum (e.g. 1 .. 3, multiple of 4)
	if ( $mof ) {
		shift( @possible_values ) until (
			! @possible_values
			|| $possible_values[0] % $mof == 0
		);
		return $possible_values[0];
	} else {
		return $possible_values[ int( rand( $#possible_values + 1 ) ) ];
	}
}

sub _random_number {
	return _random_integer( @_ );
}

sub _random_string {
	my ( $self,$schema ) = @_;

	if ( my @enum = @{ $schema->{enum} // [] } ) {
		return $enum[ int( rand( $#enum + 1 ) ) ];
	}

	return String::Random->new->randregex( $schema->{pattern} )
		if $schema->{pattern};

	my $min = $schema->{minLength} || 10;
	my $max = $schema->{maxLength} || 50;

	return String::Random->new->randpattern(
		'.' x $self->_random_integer( { minimum => $min, maximum => $max } ),
	);
}

sub _random_array {
	my ( $self,$schema ) = @_;

	my $unique = $schema->{uniqueItems};

	my $length = $self->_random_integer({
		minimum => $schema->{minItems} || 0,
		maximum => $schema->{maxItems} || 5,
	});

	my @return_items;

	if ( my $items = $schema->{items} ) {

		if ( ref( $items ) eq 'ARRAY' ) {

			ADD_ITEM: foreach my $item ( @{ $items } ) {
				$self->_add_next_array_item( \@return_items,$item,$unique )
					|| redo ADD_ITEM; # possible halting problem
			}

		} else {

			ADD_ITEM: foreach my $i ( 1 .. $length ) {
				$self->_add_next_array_item( \@return_items,$items,$unique )
					|| redo ADD_ITEM; # possible halting problem
			}

		}
	} else {
		@return_items = 1 .. $length;
	}

	return [ @return_items ];
}

sub _add_next_array_item {
	my ( $self,$array,$schema,$unique ) = @_;

	my $method = $self->_guess_method( $schema );
	my $value = $self->$method( $schema );

	if ( ! $unique ) {
		push( @{ $array },$value );
		return 1;
	}

	# unique requires us to check all existing elements of the array and only
	# add the new value if it doesn't already exist
	my %existing = map { $_ => 1 } @{ $array };

	if ( ! $existing{$value} ) {
		push( @{ $array },$value );
		return 1;
	}

	return 0;
}

sub _random_object {
	my ( $self,$schema ) = @_;

	my $object = {};

	foreach my $property ( keys( %{ $schema->{properties} } ) ) {

		# and we recurse, simple!
		$object->{$property} = $self->json_schema_to_json(
			schema => $schema->{properties}{$property},
		);
	}

	return $object;
}

sub _guess_method {
	my ( $self,$schema ) = @_;

	my $schema_type = JSON::Validator::_guess_schema_type( $schema );
	return "_random_$schema_type";
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
