class FamilyBlindUserGeofence {
  final String geofenceId;
  final String blindUserId;
  final String label;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool enabled;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FamilyBlindUserGeofence({
    required this.geofenceId,
    required this.blindUserId,
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyBlindUserGeofence.fromJson(Map<String, dynamic> json) {
    return FamilyBlindUserGeofence(
      geofenceId: (json['geofence_id'] as String? ?? '').trim(),
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      label: (json['label'] as String? ?? '').trim(),
      latitude: _parseDouble(json['latitude']) ?? 0,
      longitude: _parseDouble(json['longitude']) ?? 0,
      radiusMeters: _parseDouble(json['radius_meters']) ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
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
