#!perl

package main;

use strict;
use warnings;

use Mojolicious::Lite;
use JSON::Schema::ToJSON;

my $spec_uri = shift || die "Need a spec URI: $0 <spec_uri> <base_path>";
my $base     = shift || die "Need base path: $0 <spec_uri> <base_path>";

my $api = app->routes->under( $base )->to( cb => sub {
	my ( $c ) = @_;
	return 1;
} );

plugin OpenAPI => {
	route => $api,
	url   => $spec_uri
};

app->helper( 'openapi.not_implemented' => sub {
	my ( $c ) = @_;

	my $spec = $c->openapi->spec;

	if (my ($response) = grep { /^2/ } sort keys(%{$spec->{'responses'}})) {

		my $ret = $spec->{'responses'}{$response}{description} // '';
		if ( my $schema = $spec->{'responses'}{$response}{schema} ) {
			$ret = JSON::Schema::ToJSON->new->json_schema_to_json(
				schema => $schema
			);
		}
		return ($ret,$response);
	}

	return ({errors => [{message => 'Not implemented.', path => '/'}]}, 501);
});


app->start;
