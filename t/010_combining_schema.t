#!perl

use strict;
use warnings;

use JSON::Schema::ToJSON;
use JSON::Validator;
use Test::Most;

my $ToJSON = JSON::Schema::ToJSON->new;

isa_ok( $ToJSON,'JSON::Schema::ToJSON' );

my $schema = {
	"type" => "object",
	"properties" => {
		"some_value_any_of" => {
			"anyOf" => [
				{ "type" => "string", "maxLength" => 5 },
				{ "type" => "number", "minimum" => 0 }
			]
		}
	}
};

my $json = $ToJSON->json_schema_to_json(
    schema => $schema,
);

note explain $json;

my $validator = JSON::Validator->new;
 
$validator->schema( $schema );
my @errors = $validator->validate( $json );

ok( ! @errors,'round trip' );

done_testing();

# vim:noet:sw=4:ts=4
