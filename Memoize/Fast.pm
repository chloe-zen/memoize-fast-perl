package Memoize::Fast;
use strict;
use warnings;
use Sub::Prototype;
use Carp qw( croak );

use base 'Exporter';
our @EXPORT = qw( memoize unmemoize );

my %ORIG_SUB;

sub memoize {
    my $target = _fullname(shift, scalar caller);
    no strict 'refs';
    $ORIG_SUB{$target} = *{$target}{CODE};
    *{$target} = memoized(*{$target}{CODE}, @_);
}

sub unmemoize {
    my $target = _fullname(shift, scalar caller);
    $ORIG_SUB{$target} or croak "can't unmemoized $target - it wasn't memoized to begin with";
    *{$target} = delete $ORIG_SUB{$target}
}

sub _fullname {
    my ($n, $p) = @_;
    ref($n) and croak "can't (un)memoize a ref; try memoized() instead";
    $n =~ /::/ ? $n : "${p}::$n"
}

sub memoized {
    my ($orig_sub, %opt) = @_;
    my $orig_proto = prototype $orig_sub;

    my $range   = $opt{range} || 'all'

    my $norm    = $opt{normalizer} || sub { no warnings 'uninitialized'; join "\0", @_ };
    my $s_norm  = $opt{scalar_normalizer} || $norm;
    my $l_norm  = $opt{list_normalizer}   || $norm;

    my $s_cache = $opt{scalar_cache} || {};
    my $l_cache = $opt{list_cache}   || {};

    my $l_sub = sub {
        my ($key) = &$norm;
        exists $l_cache->{$key}
          ?   @{$l_cache->{$key}}
          : ( @{$l_cache->{$key}} = &$orig_sub )
    };
    my $s_sub = sub {
        my $key = &$norm;
        exists $s_cache->{$key}
          ?   $s_cache->{$key}
          : ( $s_cache->{$key} = &$orig_sub )
    };

    my $sub = ($range eq 'scalar') ? $s_sub
            : ($range eq 'list')   ? $l_sub
            : sub { if (wantarray) { goto &$l_sub } else { goto &$s_sub } };

    set_prototype $sub, $orig_proto if defined $orig_proto;
    $sub
}

1;
