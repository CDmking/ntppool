# GENERATED CODE - DO NOT EDIT
# Generated from: ntppool/delegation/v1/delegation.proto
# Generator: protoc-gen-perl-capi v0.1.0

package NP::CAPI::Delegation;
use strict;
use warnings;
use NP::CAPI qw(connect_rpc);
use NP::CAPI::Util qw(validate_key_value_args);
use Exporter 'import';

our @EXPORT_OK = qw(
    exchange_access_token
);

=head1 NAME

NP::CAPI::Delegation - ConnectRPC client for DelegationService

=head1 SYNOPSIS

    use NP::CAPI::Delegation qw(exchange_access_token);
    # Call ExchangeAccessToken RPC method
    my $result = exchange_access_token(
        $self->api_auth_params,      # Provides auth and context
        account => $account->{id_token},
    );


=head1 DESCRIPTION

Auto-generated ConnectRPC client for ntppool.delegation.v1.DelegationService.

This module provides Perl wrappers for calling DelegationService RPC methods
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


=head2 exchange_access_token

Call ExchangeAccessToken RPC method

B<Arguments:>

    my $result = exchange_access_token(
        $self->api_auth_params,      # Provides auth (user/session token) and context (X-Forwarded-For)
        account => $account->{id_token},  # Optional: Account selection token
        access_token => $value,       # string
    );

B<Returns:>

Hashref with structure:

    {
        code         => 200,         # HTTP status code
        status_line  => "200 OK",    # HTTP status text
        connect_code => undef,       # ConnectRPC error code (or undef)
        data         => {            # Response data
            delegated_token => ...,  # string
            expires_at => {
                seconds => ...,  # int - Represents seconds of UTC time since Unix epoch 1970-01-01T00:00:00Z. Must
 be between -62135596800 and 253402300799 inclusive (which corresponds to
 0001-01-01T00:00:00Z to 9999-12-31T23:59:59Z).
                nanos => ...,  # int - Non-negative fractions of a second at nanosecond resolution. This field is
 the nanosecond portion of the duration, not an alternative to seconds.
 Negative second values with fractions must still have non-negative nanos
 values that count forward in time. Must be between 0 and 999,999,999
 inclusive.
            },  # hashref (Timestamp)
        },
        error        => undef,       # Error message (if any)
        trace_id     => "...",       # OpenTelemetry trace ID
    }

B<Response Data Structure:>

The C<data> field contains:

=over 4

=item * B<delegated_token> (string)


=item * B<expires_at> (hashref (Timestamp))


=back

B<ConnectRPC Error Codes:>

    unauthenticated, permission_denied, internal, invalid_argument, etc.

B<Example:>

    my $result = exchange_access_token(
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

sub exchange_access_token {
    my $validation_error = validate_key_value_args('exchange_access_token', @_);
    return $validation_error if $validation_error;

    my %args = @_;

    # Extract request fields from args
    my %request = ();
    $request{'access_token'} = delete $args{'access_token'} if exists $args{'access_token'};

    return connect_rpc(
        service     => 'ntppool.delegation.v1.DelegationService',
        method      => 'ExchangeAccessToken',
        request     => \%request,
        %args  # Pass through auth, account, context
    );
}



1;

__END__

=head1 GENERATED

This module was auto-generated by protoc-gen-perl-capi from ntppool/delegation/v1/delegation.proto.

DO NOT EDIT THIS FILE MANUALLY.

=head1 SEE ALSO

L<NP::CAPI>

=cut
