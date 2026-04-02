import 'blind_location.dart';

class FamilyBlindUserLocation {
  final String blindUserId;
  final String blindUserName;
  final BlindLocation? latestLocation;

  const FamilyBlindUserLocation({
    required this.blindUserId,
    required this.blindUserName,
    required this.latestLocation,
  });

  factory FamilyBlindUserLocation.fromJson(Map<String, dynamic> json) {
    final latestLocation = json['latest_location'];
    return FamilyBlindUserLocation(
      blindUserId: (json['blind_user_id'] as String? ?? '').trim(),
      blindUserName: (json['blind_user_name'] as String? ?? '').trim(),
      latestLocation: latestLocation is Map<String, dynamic>
          ? BlindLocation.fromJson(latestLocation)
          : null,
    );
  }
}
