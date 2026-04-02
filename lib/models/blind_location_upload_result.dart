class BlindLocationUploadResult {
  final String blindUserId;
  final DateTime? recordedAt;
  final DateTime? updatedAt;

  const BlindLocationUploadResult({
    required this.blindUserId,
    required this.recordedAt,
    required this.updatedAt,
  });

  factory BlindLocationUploadResult.fromJson(Map<String, dynamic> json) {
    return BlindLocationUploadResult(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      recordedAt: _parseDateTime(json['recorded_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
