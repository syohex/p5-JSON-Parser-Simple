package JSON::Parser::Simple;
use strict;
use warnings;

use 5.010;

use Scalar::Util qw/looks_like_number/;
use Carp ();
use Encode ();
use Encode::JavaScript::UCS;

our $VERSION = '0.01';

sub new {
    my $class = shift;

    bless {
        at => 0, # The index of the current character
        ch => ' ', # The current character
        text => '',
    }, $class;
}

sub parse {
    my ($self, $source) = @_;

    $self->{text} = $source;
    $self->{at} = 0;
    $self->{ch} = ' ';

    return $self->_value();
}

sub _value {
    my $self = shift;

    # Parse a JSON value.  It could be an object, an array, atring, anumber
    # or word

    $self->_white();

    given ($self->{ch}) {
        when ('{') {
            return $self->_object();
        }
        when ('[') {
            return $self->_array();
        }
        when ('"') {
            return $self->_string();
        }
        when ('-') {
            return $self->_number();
        }
        when (m/^[0-9]$/) {
            return $self->_number();
        }
        default {
            return $self->_word();
        }
    }
}

sub _object {
    my $self = shift;

    # Parse an object value
    my $object = {};

    if ($self->{ch} eq '{') {
        $self->_next_char('{');
        $self->_white();

        if ($self->{ch} eq '}') {
            $self->_next_char('}');
            return $object;
        }

        while ($self->{ch}) {
            my $key = $self->_string();
            $self->_white();

            $self->_next_char(':');
            $object->{$key} = $self->_value();
            $self->_white();

            if ($self->{ch} eq '}') {
                $self->_next_char('}');
                return $object;
            }

            $self->_next_char(',');
            $self->_white();
        }
    }

    $self->_error("Bad object");
}

sub _array {
    my $self = shift;

    # Parse an array value
    my $array = [];

    if ( $self->{ch} eq '[' ) {
        $self->_next_char('[');
        $self->_white();

        if ($self->{ch} eq ']') {
            $self->_next_char(']');
            return $array;
        }

        while ($self->{ch}) {
            push @{$array}, $self->_value();
            $self->_white();

            if ($self->{ch} eq ']') {
                $self->_next_char(']');
                return $array;
            }

            $self->_next_char(',');
            $self->_white();
        }
    }

    $self->_error("Bad Array");
}

sub _string {
    my $self = shift;

    # Parse a string value

    my %escapee = (
        '"'  => '"',
        '\\' => '\\',
        '/'  => '/',
        b    => '\b',
        f    => '\f',
        n    => '\n',
        r    => '\r',
        t    => '\t',
    );

    my $string = '';

    # when parsing for string values, we must look for " and \ characters.

    if ($self->{ch} eq '"') {
        while ( $self->_next_char() ) {
            if ($self->{ch} eq '"') {
                $self->_next_char();
                return $string;
            } elsif ($self->{ch} eq '\\') {
                $self->_next_char();

                if ($self->{ch} eq 'u') {
                    my $uffff = '\\u';
                    for (my $i = 0; $i < 4; $i++) {
                        my $c = $self->_next_char();
                        last unless $c =~ m{^[0-9a-fA-F]$};

                        $uffff .= $c;
                    }

                    $string .= Encode::decode("JavaScript-UCS", $uffff);
                } elsif (exists $escapee{ $self->{ch} }) {
                    $string .= $escapee{ $self->{ch} };
                } else {
                    last;
                }
            } else {
                $string .= $self->{ch};
            }
        }

        $self->_error("Bad string");
    }
}

sub _number {
    my $self = shift;

    # Parse a number value
    my $str = '';

    if ($self->{ch} eq '-') {
        $str = '-';
        $self->_next_char('-');
    }

    while ($self->{ch} =~ m{^[0-9]$}) {
        $str .= $self->{ch};
        $self->_next_char();
    }

    if ($self->{ch} eq '.') {
        $str .= '.';

        while ( $self->_next_char() ) {
            last unless $self->{ch} =~ m{^[0-9]$};
            $str .= $self->{ch};
        }
    }

    if ($self->{ch} =~ m{^[eE]$}) {
        $str .= $self->{ch};
        $self->_next_char();

        if ($self->{ch} eq '-' || $self->{ch} eq '+') {
            $str .= $self->{ch};
            $self->_next_char();
        }

        while ($self->{ch} =~ m{^[0-9]$}) {
            $str .= $self->{ch};
            $self->_next_char();
        }
    }

    unless ( looks_like_number($str) ) {
        $self->_error("Bad number");
    }

    return +$str;
}

sub _word {
    my $self = shift;

    # true, false, or null
    given ($self->{ch}) {
        when ("t") {
            $self->_next_char('t');
            $self->_next_char('r');
            $self->_next_char('u');
            $self->_next_char('e');
            return 1;
        }
        when ("f") {
            $self->_next_char('f');
            $self->_next_char('a');
            $self->_next_char('l');
            $self->_next_char('s');
            $self->_next_char('e');
            return 0;
        }
        when ("n") {
            $self->_next_char('n');
            $self->_next_char('u');
            $self->_next_char('l');
            $self->_next_char('l');
            return undef;
        }
    }

    $self->_error("Unexpected '$self->{ch}'");
}

sub _next_char {
    my ($self, $c) = @_;

    # if a $c parameter is provided, verify that it matches the current character
    if ($c && $c ne $self->{ch}) {
        $self->_error("Expected: '$c', instead of '$self->{ch}' ");
    }

    # Get the next character. When there are no more characters
    # return the empty string

    $self->{ch} = substr $self->{text}, $self->{at}, 1;
    $self->{at}++;

    return $self->{ch};
}

sub _white {
    my $self = shift;

    while ($self->{ch} && $self->{ch} =~ m{^\s$}) {
        $self->_next_char();
    }
}

sub _error {
    my ($self, $message) = @_;

    my $str = sprintf "%s (at:%d, text:%s)", $message, $self->{at}, $self->{text};
    die $str;
}


1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

JSON::Parser::Simple - JSON parser in "JavaScript The Good Parts"

=head1 SYNOPSIS

  use JSON::Parser::Simple;

=head1 DESCRIPTION

JSON::Parser::Simple is JSON parser in Perl.
Original code is written in "JavaScript The Good Parts"

=head1 AUTHOR

Syohei YOSHIDA E<lt>syohex@gmail.comE<gt>

=head1 COPYRIGHT

Copyright 2012- Syohei YOSHIDA

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
