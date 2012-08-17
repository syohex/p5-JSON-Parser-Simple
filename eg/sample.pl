#!perl
use strict;
use warnings;

use JSON::Parser::Simple;
use Data::Dumper;

my $p = JSON::Parser::Simple->new;
my $result = $p->parse(' { "a" : 10, "b" : [1,true,null],
                           "c" : { "d" : "\u0068\u0065\u006c\u006c\u006f"} } ');

local $Data::Dumper::Terse = 1;
die Dumper($result);
