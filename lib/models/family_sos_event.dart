class FamilySosEvent {
  final String sosEventId;
  final String blindUserId;
  final String blindUserName;
  final String? familyDisplayName;
  final String status;
  final String? message;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final double? batteryLevel;
  final bool? isCharging;
  final DateTime? createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? emailSentAt;
  final String? emailError;
  final DateTime? updatedAt;

  const FamilySosEvent({
    required this.sosEventId,
    required this.blindUserId,
    required this.blindUserName,
    required this.familyDisplayName,
    required this.status,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.batteryLevel,
    required this.isCharging,
    required this.createdAt,
    required this.acknowledgedAt,
    required this.emailSentAt,
    required this.emailError,
    required this.updatedAt,
  });

  factory FamilySosEvent.fromJson(Map<String, dynamic> json) {
    return FamilySosEvent(
      sosEventId: (json['sos_event_id'] as String? ?? '').trim(),
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      familyDisplayName: _parseString(json['family_display_name']),
      status: (json['status'] as String? ?? '').trim(),
      message: _parseString(json['message']),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      accuracyMeters: _parseDouble(json['accuracy_meters']),
      batteryLevel: _parseDouble(json['battery_level']),
      isCharging: json['is_charging'] as bool?,
      createdAt: _parseDateTime(json['created_at']),
      acknowledgedAt: _parseDateTime(json['acknowledged_at']),
      emailSentAt: _parseDateTime(json['email_sent_at']),
      emailError: _parseString(json['email_error']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime? _parseDateTime(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
