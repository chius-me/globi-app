class LocalAuthRegistrationResult {
  final String email;
  final bool verificationRequired;
  final int codeTtlSeconds;
  final bool emailSent;

  LocalAuthRegistrationResult({
    required this.email,
    required this.verificationRequired,
    required this.codeTtlSeconds,
    required this.emailSent,
  });

  factory LocalAuthRegistrationResult.fromJson(Map<String, dynamic> json) {
    return LocalAuthRegistrationResult(
      email: json['email'] as String,
      verificationRequired: json['verification_required'] as bool? ?? true,
      codeTtlSeconds: json['code_ttl_seconds'] as int? ?? 0,
      emailSent: json['email_sent'] as bool? ?? false,
    );
  }
}
