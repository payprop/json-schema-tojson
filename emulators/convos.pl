#!perl

package main;

use strict;
use warnings;

use Mojolicious::Lite;
use JSON::Schema::ToJSON;

my $api = app->routes->under( '/api' )->to( cb => sub {
	my ( $c ) = @_;
	return 1;
} );

plugin OpenAPI => {
	route => $api,
	url   => "http://demo.convos.by/api.json",
};

app->helper( 'openapi.not_implemented' => sub {
	my ( $c ) = @_;

	my $spec = $c->openapi->spec;
	if (my ($response) = grep { /^2/ } sort keys(%{$spec->{'responses'}})) {
		my $schema = $spec->{'responses'}{$response}{schema};
		return JSON::Schema::ToJSON->new->json_schema_to_json( schema => $schema );
	}

	return {errors => [{message => 'Not implemented.', path => '/'}], status => 501};
});


app->start;
