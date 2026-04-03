import 'blind_location.dart';

class FamilyBlindUserMap {
  final String blindUserId;
  final String blindUserName;
  final int refreshIntervalSeconds;
  final int staleAfterSeconds;
  final BlindLocation? latestLocation;

  const FamilyBlindUserMap({
    required this.blindUserId,
    required this.blindUserName,
    required this.refreshIntervalSeconds,
    required this.staleAfterSeconds,
    required this.latestLocation,
  });

  factory FamilyBlindUserMap.fromJson(Map<String, dynamic> json) {
    final latestLocation = json['latest_location'];

    return FamilyBlindUserMap(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      refreshIntervalSeconds: _parseInt(json['refresh_interval_seconds']) ?? 5,
      staleAfterSeconds: _parseInt(json['stale_after_seconds']) ?? 30,
      latestLocation: latestLocation is Map<String, dynamic>
          ? BlindLocation.fromJson(latestLocation)
          : null,
    );
  }
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
