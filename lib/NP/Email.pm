package NP::Email;
use strict;
use 5.20.0;
use Combust::Config;

my $config = Combust::Config->new;

my $email_default = $config->site->{ntppool}->{email_default}
  or warn "email_default not set for 'ntppool' site";

sub address {
    my $label = shift;
    return $config->site->{ntppool}->{"email_$label"} || $email_default;
}

1;
