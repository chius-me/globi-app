class AuthConfig {
  final String issuer;
  final String discoveryUrl;
  final String clientId;
  final String? audience;
  final List<String> scopes;
  final String responseType;
  final String codeChallengeMethod;
  final String tokenEndpointAuthMethod;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? userinfoEndpoint;
  final String? revocationEndpoint;
  final String? endSessionEndpoint;
  final String jwksUri;

  AuthConfig({
    required this.issuer,
    required this.discoveryUrl,
    required this.clientId,
    this.audience,
    required this.scopes,
    required this.responseType,
    required this.codeChallengeMethod,
    required this.tokenEndpointAuthMethod,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.userinfoEndpoint,
    this.revocationEndpoint,
    this.endSessionEndpoint,
    required this.jwksUri,
  });

  factory AuthConfig.fromJson(Map<String, dynamic> json) {
    return AuthConfig(
      issuer: json['issuer'] as String,
      discoveryUrl: json['discovery_url'] as String,
      clientId: json['client_id'] as String,
      audience: json['audience'] as String?,
      scopes: (json['scopes'] as List<dynamic>).cast<String>(),
      responseType: json['response_type'] as String,
      codeChallengeMethod: json['code_challenge_method'] as String,
      tokenEndpointAuthMethod: json['token_endpoint_auth_method'] as String,
      authorizationEndpoint: json['authorization_endpoint'] as String,
      tokenEndpoint: json['token_endpoint'] as String,
      userinfoEndpoint: json['userinfo_endpoint'] as String?,
      revocationEndpoint: json['revocation_endpoint'] as String?,
      endSessionEndpoint: json['end_session_endpoint'] as String?,
      jwksUri: json['jwks_uri'] as String,
    );
  }
}
