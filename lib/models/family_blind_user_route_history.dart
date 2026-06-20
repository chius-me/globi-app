import 'blind_location.dart';

class FamilyBlindUserRouteHistory {
  final String blindUserId;
  final String blindUserName;
  final List<BlindLocation> locations;

  const FamilyBlindUserRouteHistory({
    required this.blindUserId,
    required this.blindUserName,
    required this.locations,
  });

  factory FamilyBlindUserRouteHistory.fromJson(Map<String, dynamic> json) {
    final locations = json['locations'];
    return FamilyBlindUserRouteHistory(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      locations: locations is List
          ? locations
              .whereType<Map<String, dynamic>>()
              .map(BlindLocation.fromJson)
              .toList(growable: false)
          : const [],
    );
  }
}
