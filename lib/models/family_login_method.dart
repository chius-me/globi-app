enum FamilyLoginMethod { github, local }

extension FamilyLoginMethodX on FamilyLoginMethod {
  String get storageValue => switch (this) {
    FamilyLoginMethod.github => 'github',
    FamilyLoginMethod.local => 'local',
  };

  String get displayLabel => switch (this) {
    FamilyLoginMethod.github => 'GitHub',
    FamilyLoginMethod.local => '邮箱密码',
  };
}

FamilyLoginMethod? familyLoginMethodFromStorage(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'github':
      return FamilyLoginMethod.github;
    case 'local':
      return FamilyLoginMethod.local;
    default:
      return null;
  }
}

FamilyLoginMethod? familyLoginMethodFromUserSource(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'github':
      return FamilyLoginMethod.github;
    case 'local':
    case 'local_auth':
    case 'local-email-password':
      return FamilyLoginMethod.local;
    default:
      return null;
  }
}
