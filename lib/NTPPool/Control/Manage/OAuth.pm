package NTPPool::Control::Manage::OAuth;
use strict;
use parent            qw(NTPPool::Control::Manage);
use Combust::Constant qw(OK NOT_FOUND);
use JSON::XS          ();
use NP::CAPI          qw(result_http_status);
use NP::CAPI::Connector
  qw(check_authorization decide_authorization list_grants revoke_grant);

# Connector grants belong to the user across all their Pool accounts.
sub requested_account { return undef }

sub init {
    my $self   = shift;
    my $status = $self->SUPER::init(@_);
    $self->tpl_params->{page}{disable_analytics} = 1;
    $self->cache_control('private, no-store');
    return $status;
}

my %ROUTES = (
    get => {
        '/manage/oauth/authorize' => '_authorize',
        '/manage/oauth/apps'      => '_apps',
    },
    post => {
        '/manage/oauth/authorize'   => '_decide',
        '/manage/oauth/apps/revoke' => '_revoke',
    },
);

sub render {
    my $self   = shift;
    my $method = $self->request->method;
    my $action = $ROUTES{$method} && $ROUTES{$method}{$self->request->uri}
      or return NOT_FOUND;
    $self->set_span_name("manage.oauth");

    return $self->_relogin unless $self->is_logged_in;
    if ($method eq 'post') {
        return 403 unless $self->check_auth_token;
    }
    return $self->$action;
}

# Send a signed-out user to log in. Login returns to the URL of a GET, but a
# POST would lose its form, so send it back to the page that asks again.
sub _relogin {
    my $self = shift;
    return $self->login unless $self->request->method eq 'post';
    if ($self->request->uri eq '/manage/oauth/authorize') {
        my $query = $self->req_param('query') // '';
        return $self->redirect_see_other(
            length $query
            ? "/manage/oauth/authorize?$query"
            : '/manage/oauth/authorize'
        );
    }
    return $self->redirect_see_other('/manage/oauth/apps');
}

# Decisions and revocations answer with a redirect, so the sidebar's account
# and invite lookups are only needed when one of them shows an error page.
sub _set_account_template_params {
    my $self = shift;
    return if $self->request->method eq 'post';
    return $self->SUPER::_set_account_template_params(@_);
}

sub _authorize {
    my $self   = shift;
    my $query  = $self->request->args // '';
    my $result = check_authorization($self->api_auth_params, query => $query);
    return $self->_oauth_error($result, 1) if $result->{error};
    my $data = $result->{data};
    if (my $redirect = $data->{redirect_url}) {
        return $self->redirect_see_other($redirect);
    }

    my ($status, $template, $client_name) =
      (OK, 'tpl/oauth/consent.html', $data->{client_name});
    if (defined $data->{staff_required_client_name}) {

        # Explain the refusal, and let the user send the client access_denied.
        ($status, $template, $client_name) =
          (403, 'tpl/oauth/staff_required.html', $data->{staff_required_client_name});
        $self->tpl_param('error', 'Connector approval requires an active staff account.');
    }
    return $self->_oauth_error
      unless defined $client_name && $data->{form_action_source};

    # Chromium applies form-action to the 303 back to the client.
    $self->{_consent_form_action} = $data->{form_action_source};
    $self->tpl_param('client_name',       $client_name);
    $self->tpl_param('client_host',       $data->{client_host});
    $self->tpl_param('redirect_host',     $data->{redirect_host});
    $self->tpl_param('loopback_redirect', $data->{loopback_redirect});
    $self->tpl_param('oauth_query',       $query);
    return ($status, $self->evaluate_template($template));
}

sub form_action_sources {
    my $self   = shift;
    my $source = $self->{_consent_form_action};
    return $source ? "'self' $source" : $self->SUPER::form_action_sources;
}

sub _decide {
    my $self   = shift;
    my $result = decide_authorization(
        $self->api_auth_params,
        query   => $self->req_param('query') // '',
        approve => ($self->req_param('decision') // '') eq 'approve'
        ? JSON::XS::true
        : JSON::XS::false,
    );
    return $self->_oauth_error($result, 1) if $result->{error};
    my $redirect = $result->{data}{redirect_url} or return $self->_oauth_error;
    return $self->redirect_see_other($redirect);
}

sub _apps {
    my $self = shift;
    $self->tpl_params->{page}{is_connected_apps} = 1;
    my $result = list_grants($self->api_auth_params);
    return $self->_oauth_error($result) if $result->{error};
    $self->tpl_param('grants', $result->{data}{grants} || []);
    return (OK, $self->evaluate_template('tpl/oauth/apps.html'));
}

sub _revoke {
    my $self = shift;
    my $result =
      revoke_grant($self->api_auth_params,
          grant_id => $self->req_param('grant_id') // '');
    return $self->_oauth_error($result) if $result->{error};
    return $self->redirect_see_other('/manage/oauth/apps');
}

sub _oauth_error {
    my ($self, $result, $authorization) = @_;
    my ($status) = $result ? result_http_status($result) : 503;

    # The API no longer accepts the session.
    return $self->_relogin if $status == 401;

    my $message = 'Connected apps are temporarily unavailable.';
    if ($authorization && $status == 403) {
        $message = 'Connector approval requires an active staff account.';
    }
    elsif ($authorization && $status == 400) {
        $message = 'This connector authorization request is invalid.';
    }
    elsif ($status == 400) {
        $message = 'This connected app request is invalid.';
    }

    $self->SUPER::_set_account_template_params if $self->request->method eq 'post';
    $self->tpl_param('error', $message);
    return ($status, $self->evaluate_template('tpl/oauth/error.html'));
}

1;
