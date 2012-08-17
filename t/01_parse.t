use strict;
use warnings;
use Test::More;

use JSON::XS;
use JSON::Parser::Simple;

my $p = JSON::Parser::Simple->new;

subtest 'basic' => sub {
    my $got;

    $got = $p->parse('"a"');
    is($got, 'a', "string");

    $got = $p->parse('100');
    is($got, '100', "number");

    $got = $p->parse('[1,2,3]');
    is_deeply($got, [1,2,3], "array");

    $got = $p->parse('{ "a" : 100, "b" : "foo"}');
    is_deeply($got, { a => 100, b => 'foo'}, "object");

    $got = $p->parse('[true,false,null]');
    is_deeply($got, [1,0,undef], "reserved word");
};

subtest 'complex' => sub {
    my $got;

    my $input = {
        aaa => {
            bbb => {
                ccc => [ "a", "b", [ qw/c d/] ],
            }
        },
        bbb => "foo",
        ccc => [
            { aaa => 'foo', bbb => 'bar'},
        ],
    };

    my $encoded = encode_json($input);
    $got = $p->parse($encoded);
    is_deeply($got, $input, 'complex data');
};

subtest 'ucs' => sub {
    my $got;

    $got = $p->parse('"\u0068\u0065\u006c\u006c\u006f"');
    is($got, "hello", "Unicode UCS");
};

done_testing;
