# NAME

JSON::Schema::ToJSON - Generate example JSON structures from JSON Schema definitions

# VERSION

0.01\_01

# SYNOPSIS

    use JSON::Schema::ToJSON;

    my $to_json  = JSON::Schema::ToJSON->new;

    my $perl_string_hash_or_arrayref = $to_json->json_schema_to_json(
      schema     => $already_parsed_json_schema,  # either this
      schema_str => '{ "type" : "boolean" }',     # or this
    );

# DESCRIPTION

[JSON::Schema::ToJSON](https://metacpan.org/pod/JSON::Schema::ToJSON) is a class for generating "fake" or "example" JSON data
structures from JSON Schema structures.

Note this distribution is currently **EXPERIMENTAL** and subject to breaking changes.

# LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/json-schema-tojson

# AUTHOR

Lee Johnson - `leejo@cpan.org`
