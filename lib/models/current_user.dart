class CurrentUser {
  final String? sub;
  final String? preferredUsername;
  final String? name;
  final String? email;
  final bool emailVerified;
  final String? picture;
  final String source;

  CurrentUser({
    this.sub,
    this.preferredUsername,
    this.name,
    this.email,
    this.emailVerified = false,
    this.picture,
    required this.source,
  });

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      sub: json['sub'] as String?,
      preferredUsername: json['preferred_username'] as String?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      emailVerified: json['email_verified'] as bool? ?? false,
      picture: json['picture'] as String?,
      source: json['source'] as String? ?? 'unknown',
    );
  }

  String get displayName => name ?? preferredUsername ?? email ?? 'Unknown';
}
