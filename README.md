# NAME

JSON::Schema::ToJSON - Generate example JSON structures from JSON Schema definitions

# VERSION

0.02

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

# BUGS, CAVEATS, AND GOTCHAS

Bugs? Almost certainly.

Caveats? The implementation is currently incomplete, this is a work in progress so
using some of the more edge case JSON schema options (oneOf, formats, required, not,
etc) will not generate representative JSON so they will not validate against the
schema on a round trip.

Gotchas? The data generated is completely random, don't expect it to be the same
across runs or calls. The data is also meaningless in terms of what it represents
such that an object property of "name" that is a string will be generated as, for
example, "kj02@#fjs01je#$42wfjs" - The JSON generated is so you have a representative
**structure**, not representative **data**.

# LICENSE

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. If you would like to contribute documentation,
features, bug fixes, or anything else then please raise an issue / pull request:

    https://github.com/Humanstate/json-schema-tojson

# AUTHOR

Lee Johnson - `leejo@cpan.org`
