package JSON::Schema::ToJSON;

use strict;
use warnings;

use Mojo::Base -base;
use Cpanel::JSON::XS;
use JSON::Validator;
use String::Random;

our $VERSION = '0.03';

has _validator  => sub { JSON::Validator->new };
has _str_rand   => sub { String::Random->new };

has example_key => sub { 0 };

sub json_schema_to_json {
	my ( $self,%args ) = @_;

	my $schema = $args{schema}; # an already parsed JSON schema

	if ( ! $schema ) {
		$schema = $args{schema_str} # an unparsed JSON schema
			|| die "json_schema_to_json needs schema or schema_str arg";

		eval { $schema = decode_json( $schema ); }
		or do { die "json_schema_to_json failed to parse schema: $@" };
	}

	$self->example_key( $args{example_key} ) if $args{example_key};

	$self->_validator->schema( $schema );
	$schema = $self->_validator->schema->data;

	my $method = $self->_guess_method( $schema );
	return $self->$method( $schema );
}

sub _example_from_spec {
	my ( $self,$schema ) = @_;

	# spec/schema can contain examples that we could use as mock data

	return $schema->{ $self->example_key } # OpenAPI specific
		if $self->example_key && $schema->{ $self->example_key };

	return ();
}

sub _random_boolean {
	my ( $self,$schema ) = @_;

	return $self->_example_from_spec( $schema )
		if scalar $self->_example_from_spec( $schema );

	return rand > 0.5
		? Cpanel::JSON::XS::true
		: Cpanel::JSON::XS::false
}

sub _random_integer {
	my ( $self,$schema ) = @_;

	return $self->_example_from_spec( $schema )
		if scalar $self->_example_from_spec( $schema );

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
				? 1 .. $max
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
	my ( $self,$schema ) = @_;

	return $self->_example_from_spec( $schema )
		if scalar $self->_example_from_spec( $schema );

	return $self->_random_integer( $schema ) + $self->_random_integer( $schema ) / 10;
}

sub _random_string {
	my ( $self,$schema ) = @_;

	return $self->_example_from_spec( $schema )
		if scalar $self->_example_from_spec( $schema );

	if ( my @enum = @{ $schema->{enum} // [] } ) {
		return $enum[ int( rand( $#enum + 1 ) ) ];
	}

	return $self->_str_rand->randregex( $schema->{pattern} )
		if $schema->{pattern};

	my $min = $schema->{minLength}
		|| ( $schema->{maxLength} ? $schema->{maxLength} - 1 : 10 );

	my $max = $schema->{maxLength}
		|| ( $schema->{minLength} ? $schema->{minLength} + 1 : 50 );

	return $self->_str_rand->randpattern(
		'.' x $self->_random_integer( { minimum => $min, maximum => $max } ),
	);
}

sub _random_array {
	my ( $self,$schema ) = @_;

	my $unique = $schema->{uniqueItems};

	my $length = $self->_random_integer({
		minimum => $schema->{minItems}
			|| ( $schema->{maxItems} ? $schema->{maxItems} - 1 : 1 ),
		maximum => $schema->{maxItems}
			|| ( $schema->{minItems} ? $schema->{minItems} + 1 : 5 )
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
	my $required;
	my %properties = map { $_ => 1 } keys( %{ $schema->{properties} } );

	if ( $required = $schema->{required} ) {
		# we have a list of required properties, just use those
		%properties = map { $_ => 1 } @{ $required };
	}

	# check max/min properties requirements
	my $min = $schema->{minProperties}
		|| ( $schema->{maxProperties} ? $schema->{maxProperties} - 1 : undef );

	my $max = $schema->{maxProperties}
		|| ( $schema->{minProperties} ? $schema->{minProperties} + 1 : undef );

	if ( $min && scalar( keys( %properties ) ) < $min ) {
		# we have too few properties
		if ( $max ) {
			# add more properties until we have enough
			MAX_PROP: foreach my $property ( keys( %{ $schema->{properties} } ) ) {
				$properties{$property} = 1;
				last MAX_PROP if scalar( keys( %properties ) ) == $min;
			}
		} else {
			# no max, just make use of all properties
			%properties = map { $_ => 1 } keys( %{ $schema->{properties} } );
		}
	}

	if ( $max && scalar( keys( %properties ) ) > $max ) {
		# we have too many properties, delete some (except those required)
		# until we are below the max permitted amount
		MIN_PROP: foreach my $property ( keys( %{ $schema->{properties} } ) ) {

			delete( $properties{$property} ) if (
				# we can delete, we don't have any required properties
				! $required

				# or this property is not amongst the list of required properties
				|| ! grep { $_ eq $property } @{ $required }
			);

			last MIN_PROP if scalar( keys( %properties ) ) <= $max;
		}
	}

	foreach my $property ( keys %properties ) {

		my $method = $self->_guess_method( $schema->{properties}{$property} );
		$object->{$property} = $self->$method( $schema->{properties}{$property} );
	}

	return $object;
}

sub _random_null { undef }

sub _guess_method {
	my ( $self,$schema ) = @_;

	if ( ref( $schema->{'type'} ) eq 'ARRAY' ) {
		$schema->{'type'} = $schema->{'type'}->[
			int( rand( scalar( @{ $schema->{'type'} } ) ) )
		];
	}

	# danger danger! accessing private method from elsewhere
	my $schema_type = JSON::Validator::_guess_schema_type( $schema ) // 'null';
	return "_random_$schema_type";
}

=encoding utf8

=head1 NAME

JSON::Schema::ToJSON - Generate example JSON structures from JSON Schema definitions

=head1 VERSION

0.03

=head1 SYNOPSIS

    use JSON::Schema::ToJSON;

    my $to_json  = JSON::Schema::ToJSON->new(
        example_key => undef, # set to a key to take example from
    );

    my $perl_string_hash_or_arrayref = $to_json->json_schema_to_json(
        schema     => $already_parsed_json_schema,  # either this
        schema_str => '{ "type" : "boolean" }',     # or this
    );

=head1 DESCRIPTION

L<JSON::Schema::ToJSON> is a class for generating "fake" or "example" JSON data
structures from JSON Schema structures.

Note this distribution is currently B<EXPERIMENTAL> and subject to breaking changes.

=head1 CONSTRUCTOR ARGUMENTS

=head2 example_key

The key that will be used to find example data for use in the returned structure. In
the case of the following schema:

    {
        "type" : "object",
        "properties" : {
            "id" : {
                "type" : "string",
                "description" : "ID of the payment.",
                "x-example" : "123ABC"
            }
        }
    }

Setting example_key to C<x-example> will make the generator return the content of
the C<"x-example"> (123ABC) rather than a random string/int/etc. This is more so
for things like OpenAPI specifications.

You can set this to any key you like, although be careful as you could end up with
invalid data being used (for example an integer field and then using the description
key as the content would not be sensible or valid).

=head1 METHODS

=head2 json_schema_to_json

    my $perl_string_hash_or_arrayref = $to_json->json_schema_to_json(
        schema     => $already_parsed_json_schema,  # either this
        schema_str => '{ "type" : "boolean" }',     # or this
    );

Returns a randomly generated representative data structure that corresponds to the
passed JSON schema. Can take either an already parsed JSON Schema or the raw JSON
Schema string.

=head1 BUGS, CAVEATS, AND GOTCHAS

Bugs? Almost certainly.

Caveats? The implementation is currently incomplete, this is a work in progress so
using some of the more edge case JSON schema validation options will not generate
representative JSON so they will not validate against the schema on a round trip.
These include:

    additionalItems
    patternProperties
    additionalProperties
    dependencies
    allOf
    anyOf
    oneOf
    not

It is also entirely possible to pass a schema that could never be validated, but
will result in a generated structure anyway, example: an integer that has a "minimum"
value of 2, "maximum" value of 4, and must be a "multipleOf" 5 - a nonsensical
combination. Having an array with "allOf" and "minItems" or "maxItems" would also be
nonsensical.

Gotchas? The data generated is completely random, don't expect it to be the same
across runs or calls. The data is also meaningless in terms of what it represents
such that an object property of "name" that is a string will be generated as, for
example, "kj02@#fjs01je#$42wfjs" - The JSON generated is so you have a representative
B<structure>, not representative B<data>. Set example keys in your schema and then
set the C<example_key> in the constructor if you want this to be repeatable and/or
more representative.

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
