#!perl

use strict;
use warnings;

use JSON::Schema::ToJSON;
use Test::Most;

my $ToJSON = JSON::Schema::ToJSON->new;

isa_ok( $ToJSON,'JSON::Schema::ToJSON' );

isa_ok(
	$ToJSON->json_schema_to_json(
		schema_str => '{ "type" : "boolean" }',
	),
	'JSON::PP::Boolean',
	'boolean',
);

is(
	$ToJSON->json_schema_to_json(
		schema_str => '{
			"type": "integer",
			"minimum": 25,
			"maximum": 75,
			"exclusiveMinimum": true,
			"exclusiveMaximum": true
		}'
	),
	1,
	'integer',
);

done_testing();

# vim:noet:sw=4:ts=4
