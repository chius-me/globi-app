class BlindFamilyCall {
  final String blindUserId;
  final String familyDisplayName;
  final String? familyPhone;
  final String telUri;

  const BlindFamilyCall({
    required this.blindUserId,
    required this.familyDisplayName,
    required this.familyPhone,
    required this.telUri,
  });

  factory BlindFamilyCall.fromJson(Map<String, dynamic> json) {
    return BlindFamilyCall(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      familyDisplayName: (json['family_display_name'] as String? ?? '').trim(),
      familyPhone: _parseString(json['family_phone']),
      telUri: (json['tel_uri'] as String? ?? '').trim(),
    );
  }
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
