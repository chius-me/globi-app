class AuthTokens {
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final int expiresAt;
  final String? refreshToken;
  final String? idToken;
  final String? scope;

  AuthTokens({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.expiresAt,
    this.refreshToken,
    this.idToken,
    this.scope,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      expiresAt: json['expires_at'] as int,
      refreshToken: json['refresh_token'] as String?,
      idToken: json['id_token'] as String?,
      scope: json['scope'] as String?,
    );
  }

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= expiresAt;
  }

  bool get isAboutToExpire {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now >= (expiresAt - 60);
  }
}
