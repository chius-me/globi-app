class BlindIdentity {
  final String blindUserId;
  final String blindUserName;
  final String familyDisplayName;
  final String? deviceLabel;
  final DateTime? linkedAt;
  final DateTime? lastSeenAt;
  final DateTime? lastLocationAt;

  const BlindIdentity({
    required this.blindUserId,
    required this.blindUserName,
    required this.familyDisplayName,
    required this.deviceLabel,
    required this.linkedAt,
    required this.lastSeenAt,
    required this.lastLocationAt,
  });

  factory BlindIdentity.fromJson(Map<String, dynamic> json) {
    return BlindIdentity(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      familyDisplayName: (json['family_display_name'] as String? ?? '').trim(),
      deviceLabel: _parseString(json['device_label']),
      linkedAt: _parseDateTime(json['linked_at']),
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      lastLocationAt: _parseDateTime(json['last_location_at']),
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
