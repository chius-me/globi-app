class BlindLinkResult {
  final String blindUserId;
  final String blindUserName;
  final String familyDisplayName;
  final DateTime? linkedAt;
  final String blindAccessToken;
  final String tokenType;
  final String? deviceLabel;

  const BlindLinkResult({
    required this.blindUserId,
    required this.blindUserName,
    required this.familyDisplayName,
    required this.linkedAt,
    required this.blindAccessToken,
    required this.tokenType,
    required this.deviceLabel,
  });

  factory BlindLinkResult.fromJson(Map<String, dynamic> json) {
    return BlindLinkResult(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      familyDisplayName: (json['family_display_name'] as String? ?? '').trim(),
      linkedAt: _parseDateTime(json['linked_at']),
      blindAccessToken: (json['blind_access_token'] as String? ?? '').trim(),
      tokenType: (json['token_type'] as String? ?? 'Bearer').trim(),
      deviceLabel: _parseString(json['device_label']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
