class FamilyProfile {
  final String? email;
  final String? phone;
  final String? name;

  const FamilyProfile({this.email, this.phone, this.name});

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      email: _parseString(json['email']),
      phone: _parseString(json['phone']),
      name: _parseString(json['name']),
    );
  }
}

String? _parseString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}
