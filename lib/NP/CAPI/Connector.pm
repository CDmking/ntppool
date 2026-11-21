# GENERATED CODE - DO NOT EDIT
# Generated from: ntppool/connector/v1/connector.proto
# Generator: protoc-gen-perl-capi v0.1.0

package NP::CAPI::Connector;
use strict;
use warnings;
use NP::CAPI qw(connect_rpc);
use NP::CAPI::Util qw(validate_key_value_args);
use Exporter 'import';

our @EXPORT_OK = qw(
    check_authorization
    decide_authorization
    list_grants
    revoke_grant
);

=head1 NAME

NP::CAPI::Connector - ConnectRPC client for ConnectorService

=head1 SYNOPSIS

    use NP::CAPI::Connector qw(check_authorization decide_authorization list_grants revoke_grant);
    # CheckAuthorization validates an authorization query for the signed-in user.
    my $result = check_authorization(
        $self->api_auth_params,      # Provides auth and context
        account => $account->{id_token},
    );

    # DecideAuthorization returns the client redirect. Any signed-in user may deny; approving requires active staff.
    my $result = decide_authorization(
        $self->api_auth_params,      # Provides auth and context
        account => $account->{id_token},
    );

    # Call ListGrants RPC method
    my $result = list_grants(
        $self->api_auth_params,      # Provides auth and context
        account => $account->{id_token},
    );

    # Call RevokeGrant RPC method
    my $result = revoke_grant(
        $self->api_auth_params,      # Provides auth and context
        account => $account->{id_token},
    );


=head1 DESCRIPTION

Auto-generated ConnectRPC client for ntppool.connector.v1.ConnectorService.

This module provides Perl wrappers for calling ConnectorService RPC methods
over HTTP using the ConnectRPC protocol.

=head1 RESPONSE FORMAT

All methods return a hashref with the following structure:

=over 4

=item * B<code> (int)

HTTP status code (e.g., 200 for success, 401 for unauthenticated, 403 for permission denied, 500 for internal errors).

=item * B<status_line> (string)

HTTP status text (e.g., "200 OK", "401 Unauthorized").

=item * B<connect_code> (string or undef)

ConnectRPC error code if the request failed. Possible values include:

    - unauthenticated: No valid authentication provided
    - permission_denied: User lacks required permissions
    - invalid_argument: Request validation failed
    - not_found: Requested resource not found
    - internal: Server-side error occurred
    - unavailable: Service temporarily unavailable

Will be C<undef> for successful requests.

=item * B<data> (hashref or undef)

Response data on success. Contains method-specific fields with the actual response payload.
The structure and available fields vary by method - see each method's documentation below for
the complete list of response fields, their types, and descriptions.

Will be C<undef> if an error occurred.

=item * B<error> (string or undef)

Human-readable error message if the request failed. Will be C<undef> for successful requests.

=item * B<trace_id> (string)

OpenTelemetry trace ID for request tracing and debugging. Include this when reporting issues.

=back

=head2 Error Handling Example

    my $result = some_method(...);

    if ($result->{error}) {
        warn "Request failed: $result->{error}";
        warn "ConnectRPC code: $result->{connect_code}" if $result->{connect_code};
        warn "Trace ID: $result->{trace_id}";
        return;
    }

    # Success - use $result->{data}
    my $data = $result->{data};

=head1 METHODS


=head2 check_authorization

CheckAuthorization validates an authorization query for the signed-in user.

B<Arguments:>

    my $result = check_authorization(
        $self->api_auth_params,      # Provides auth (user/session token) and context (X-Forwarded-For)
        account => $account->{id_token},  # Optional: Account selection token
        query => $value,       # string
    );

B<Returns:>

Hashref with structure:

    {
        code         => 200,         # HTTP status code
        status_line  => "200 OK",    # HTTP status text
        connect_code => undef,       # ConnectRPC error code (or undef)
        data         => {            # Response data
            client_name => ...,  # string - Show the consent page.
            redirect_url => ...,  # string - Send the browser back with an error.
            staff_required_client_name => ...,  # string - The user isn't active staff: explain that and offer only a deny that returns to this client.
            form_action_source => ...,  # string - CSP form-action source that lets the consent form follow the 303 back to the client.
        },
        error        => undef,       # Error message (if any)
        trace_id     => "...",       # OpenTelemetry trace ID
    }

B<ConnectRPC Error Codes:>

    unauthenticated, permission_denied, internal, invalid_argument, etc.

B<Example:>

    my $result = check_authorization(
        $self->api_auth_params,           # Provides auth and context
        account => $account->{id_token},  # Account from hashref
    );

    if ($result->{error}) {
        warn "Error: $result->{error}";
    } else {
        my $data = $result->{data};
        # Use response fields...
    }

=cut

sub check_authorization {
    my $validation_error = validate_key_value_args('check_authorization', @_);
    return $validation_error if $validation_error;

    my %args = @_;

    # Extract request fields from args
    my %request = ();
    $request{'query'} = delete $args{'query'} if exists $args{'query'};

    return connect_rpc(
        service     => 'ntppool.connector.v1.ConnectorService',
        method      => 'CheckAuthorization',
        request     => \%request,
        %args  # Pass through auth, account, context
    );
}


=head2 decide_authorization

DecideAuthorization returns the client redirect. Any signed-in user may deny; approving requires active staff.

B<Arguments:>

    my $result = decide_authorization(
        $self->api_auth_params,      # Provides auth (user/session token) and context (X-Forwarded-For)
        account => $account->{id_token},  # Optional: Account selection token
        query => $value,       # string
        approve => $value,       # bool
    );

B<Returns:>

Hashref with structure:

    {
        code         => 200,         # HTTP status code
        status_line  => "200 OK",    # HTTP status text
        connect_code => undef,       # ConnectRPC error code (or undef)
        data         => {            # Response data
            redirect_url => ...,  # string
        },
        error        => undef,       # Error message (if any)
        trace_id     => "...",       # OpenTelemetry trace ID
    }

B<ConnectRPC Error Codes:>

    unauthenticated, permission_denied, internal, invalid_argument, etc.

B<Example:>

    my $result = decide_authorization(
        $self->api_auth_params,           # Provides auth and context
        account => $account->{id_token},  # Account from hashref
    );

    if ($result->{error}) {
        warn "Error: $result->{error}";
    } else {
        my $data = $result->{data};
        # Use response fields...
    }

=cut

sub decide_authorization {
    my $validation_error = validate_key_value_args('decide_authorization', @_);
    return $validation_error if $validation_error;

    my %args = @_;

    # Extract request fields from args
    my %request = ();
    $request{'query'} = delete $args{'query'} if exists $args{'query'};
    $request{'approve'} = delete $args{'approve'} if exists $args{'approve'};

    return connect_rpc(
        service     => 'ntppool.connector.v1.ConnectorService',
        method      => 'DecideAuthorization',
        request     => \%request,
        %args  # Pass through auth, account, context
    );
}


=head2 list_grants

Call ListGrants RPC method

B<Arguments:>

    my $result = list_grants(
        $self->api_auth_params,      # Provides auth (user/session token) and context (X-Forwarded-For)
        account => $account->{id_token},  # Optional: Account selection token
    );

B<Returns:>

Hashref with structure:

    {
        code         => 200,         # HTTP status code
        status_line  => "200 OK",    # HTTP status text
        connect_code => undef,       # ConnectRPC error code (or undef)
        data         => {            # Response data
            grants => [
            {
                grant_id => ...,  # string
                client_name => ...,  # string
                created_at => ...,  # hashref (Timestamp)
                expires_at => ...,  # hashref (Timestamp)
                revoked => ...,  # bool
            },
            # ... more items
        ],  # arrayref[hashref (Grant)]
        },
        error        => undef,       # Error message (if any)
        trace_id     => "...",       # OpenTelemetry trace ID
    }

B<Response Data Structure:>

The C<data> field contains:

=over 4

=item * B<grants> (arrayref[hashref (Grant)])


=back

B<ConnectRPC Error Codes:>

    unauthenticated, permission_denied, internal, invalid_argument, etc.

B<Example:>

    my $result = list_grants(
        $self->api_auth_params,           # Provides auth and context
        account => $account->{id_token},  # Account from hashref
    );

    if ($result->{error}) {
        warn "Error: $result->{error}";
    } else {
        my $data = $result->{data};
        # Use response fields...
    }

=cut

sub list_grants {
    my $validation_error = validate_key_value_args('list_grants', @_);
    return $validation_error if $validation_error;

    my %args = @_;

    # Extract request fields from args
    my %request = ();

    return connect_rpc(
        service     => 'ntppool.connector.v1.ConnectorService',
        method      => 'ListGrants',
        request     => \%request,
        %args  # Pass through auth, account, context
    );
}


=head2 revoke_grant

Call RevokeGrant RPC method

B<Arguments:>

    my $result = revoke_grant(
        $self->api_auth_params,      # Provides auth (user/session token) and context (X-Forwarded-For)
        account => $account->{id_token},  # Optional: Account selection token
        grant_id => $value,       # string
    );

B<Returns:>

Hashref with structure:

    {
        code         => 200,         # HTTP status code
        status_line  => "200 OK",    # HTTP status text
        connect_code => undef,       # ConnectRPC error code (or undef)
        data         => {            # Response data
        },
        error        => undef,       # Error message (if any)
        trace_id     => "...",       # OpenTelemetry trace ID
    }

B<ConnectRPC Error Codes:>

    unauthenticated, permission_denied, internal, invalid_argument, etc.

B<Example:>

    my $result = revoke_grant(
        $self->api_auth_params,           # Provides auth and context
        account => $account->{id_token},  # Account from hashref
    );

    if ($result->{error}) {
        warn "Error: $result->{error}";
    } else {
        my $data = $result->{data};
        # Use response fields...
    }

=cut

sub revoke_grant {
    my $validation_error = validate_key_value_args('revoke_grant', @_);
    return $validation_error if $validation_error;

    my %args = @_;

    # Extract request fields from args
    my %request = ();
    $request{'grant_id'} = delete $args{'grant_id'} if exists $args{'grant_id'};

    return connect_rpc(
        service     => 'ntppool.connector.v1.ConnectorService',
        method      => 'RevokeGrant',
        request     => \%request,
        %args  # Pass through auth, account, context
    );
}



1;

__END__

=head1 GENERATED

This module was auto-generated by protoc-gen-perl-capi from ntppool/connector/v1/connector.proto.

DO NOT EDIT THIS FILE MANUALLY.

=head1 SEE ALSO

L<NP::CAPI>

=cut
