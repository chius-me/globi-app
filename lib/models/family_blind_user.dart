import 'blind_location.dart';

class FamilyBlindUser {
  final String blindUserId;
  final String blindUserName;
  final String? deviceLabel;
  final DateTime? linkedAt;
  final DateTime? lastSeenAt;
  final DateTime? lastLocationAt;
  final BlindLocation? latestLocation;

  const FamilyBlindUser({
    required this.blindUserId,
    required this.blindUserName,
    required this.deviceLabel,
    required this.linkedAt,
    required this.lastSeenAt,
    required this.lastLocationAt,
    required this.latestLocation,
  });

  factory FamilyBlindUser.fromJson(Map<String, dynamic> json) {
    final latestLocation = json['latest_location'];
    return FamilyBlindUser(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      deviceLabel: _parseString(json['device_label']),
      linkedAt: _parseDateTime(json['linked_at']),
      lastSeenAt: _parseDateTime(json['last_seen_at']),
      lastLocationAt: _parseDateTime(json['last_location_at']),
      latestLocation: latestLocation is Map<String, dynamic>
          ? BlindLocation.fromJson(latestLocation)
          : null,
    );
  }

  FamilyBlindUser copyWith({
    String? blindUserId,
    String? blindUserName,
    String? deviceLabel,
    DateTime? linkedAt,
    DateTime? lastSeenAt,
    DateTime? lastLocationAt,
    BlindLocation? latestLocation,
    bool clearLatestLocation = false,
  }) {
    return FamilyBlindUser(
      blindUserId: blindUserId ?? this.blindUserId,
      blindUserName: blindUserName ?? this.blindUserName,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      linkedAt: linkedAt ?? this.linkedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastLocationAt: lastLocationAt ?? this.lastLocationAt,
      latestLocation: clearLatestLocation
          ? null
          : latestLocation ?? this.latestLocation,
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
