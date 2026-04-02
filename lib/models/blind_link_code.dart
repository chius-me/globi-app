class BlindLinkCode {
  final String authorizationCode;
  final String blindUserName;
  final DateTime? expiresAt;
  final int? expiresIn;

  const BlindLinkCode({
    required this.authorizationCode,
    required this.blindUserName,
    this.expiresAt,
    this.expiresIn,
  });

  factory BlindLinkCode.fromJson(Map<String, dynamic> json) {
    return BlindLinkCode(
      authorizationCode: (json['authorization_code'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      expiresAt: _parseDateTime(json['expires_at']),
      expiresIn: _parseInt(json['expires_in']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
