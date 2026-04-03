import 'family_profile.dart';

class FamilyProfileBootstrap {
  final bool profileCompleted;
  final String? suggestedEmail;
  final String? suggestedName;
  final FamilyProfile? profile;

  const FamilyProfileBootstrap({
    required this.profileCompleted,
    required this.suggestedEmail,
    required this.suggestedName,
    required this.profile,
  });

  factory FamilyProfileBootstrap.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'];

    return FamilyProfileBootstrap(
      profileCompleted: json['profile_completed'] as bool? ?? false,
      suggestedEmail: _parseString(json['suggested_email']),
      suggestedName: _parseString(json['suggested_name']),
      profile: profile is Map<String, dynamic>
          ? FamilyProfile.fromJson(profile)
          : null,
    );
  }

  String? get initialEmail => profile?.email ?? suggestedEmail;
  String? get initialName => profile?.name ?? suggestedName;
  String? get initialPhone => profile?.phone;
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
