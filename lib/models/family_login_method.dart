enum FamilyLoginMethod { oidc, local }

extension FamilyLoginMethodX on FamilyLoginMethod {
  String get storageValue => switch (this) {
    FamilyLoginMethod.oidc => 'oidc',
    FamilyLoginMethod.local => 'local',
  };

  String get displayLabel => switch (this) {
    FamilyLoginMethod.oidc => 'Authentik',
    FamilyLoginMethod.local => '邮箱密码',
  };
}

FamilyLoginMethod? familyLoginMethodFromStorage(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'oidc':
      return FamilyLoginMethod.oidc;
    case 'local':
      return FamilyLoginMethod.local;
    default:
      return null;
  }
}

FamilyLoginMethod? familyLoginMethodFromUserSource(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'oidc':
    case 'authentik':
      return FamilyLoginMethod.oidc;
    case 'local':
    case 'local_auth':
    case 'local-email-password':
      return FamilyLoginMethod.local;
    default:
      return null;
  }
}
