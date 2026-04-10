import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/family_login_method.dart';

class SecureStorageService {
  static const _keyAppMode = 'app_mode';
  static const _keyAccessToken = 'access_token';
  static const _keyRefreshToken = 'refresh_token';
  static const _keyIdToken = 'id_token';
  static const _keyExpiresAt = 'expires_at';
  static const _keyFamilyLoginMethod = 'family_login_method';
  static const _keyPkceCodeVerifier = 'pkce_code_verifier';
  static const _keyPkceCodeChallenge = 'pkce_code_challenge';
  static const _keyPkceState = 'pkce_state';
  static const _keyPkceNonce = 'pkce_nonce';
  static const _keyBlindAccessToken = 'blind_access_token';
  static const _keyBlindUserId = 'blind_user_id';
  static const _keyBlindUserName = 'blind_user_name';
  static const _keyBlindFamilyDisplayName = 'blind_family_display_name';
  static const _keyBlindDeviceLabel = 'blind_device_label';
  static const _keyBlindLinkedAt = 'blind_linked_at';

  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveAppMode(String mode) =>
      _storage.write(key: _keyAppMode, value: mode);

  Future<String?> getAppMode() => _storage.read(key: _keyAppMode);

  Future<void> clearAppMode() => _storage.delete(key: _keyAppMode);

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    String? idToken,
    required int expiresAt,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _writeOrDelete(_keyRefreshToken, refreshToken);
    await _writeOrDelete(_keyIdToken, idToken);
    await _storage.write(key: _keyExpiresAt, value: expiresAt.toString());
  }

  Future<void> saveFamilyLoginMethod(FamilyLoginMethod loginMethod) {
    return _storage.write(
      key: _keyFamilyLoginMethod,
      value: loginMethod.storageValue,
    );
  }

  Future<FamilyLoginMethod?> getFamilyLoginMethod() async {
    final value = await _storage.read(key: _keyFamilyLoginMethod);
    return familyLoginMethodFromStorage(value);
  }

  Future<void> clearFamilyLoginMethod() {
    return _storage.delete(key: _keyFamilyLoginMethod);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);
  Future<String?> getIdToken() => _storage.read(key: _keyIdToken);

  Future<int?> getExpiresAt() async {
    final val = await _storage.read(key: _keyExpiresAt);
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> savePendingPkce({
    required String codeVerifier,
    required String codeChallenge,
    required String state,
    required String nonce,
  }) async {
    await _storage.write(key: _keyPkceCodeVerifier, value: codeVerifier);
    await _storage.write(key: _keyPkceCodeChallenge, value: codeChallenge);
    await _storage.write(key: _keyPkceState, value: state);
    await _storage.write(key: _keyPkceNonce, value: nonce);
  }

  Future<Map<String, String>?> getPendingPkce() async {
    final codeVerifier = await _storage.read(key: _keyPkceCodeVerifier);
    final codeChallenge = await _storage.read(key: _keyPkceCodeChallenge);
    final state = await _storage.read(key: _keyPkceState);
    final nonce = await _storage.read(key: _keyPkceNonce);

    if (codeVerifier == null ||
        codeChallenge == null ||
        state == null ||
        nonce == null) {
      return null;
    }

    return {
      'code_verifier': codeVerifier,
      'code_challenge': codeChallenge,
      'state': state,
      'nonce': nonce,
    };
  }

  Future<void> clearPendingPkce() async {
    await _storage.delete(key: _keyPkceCodeVerifier);
    await _storage.delete(key: _keyPkceCodeChallenge);
    await _storage.delete(key: _keyPkceState);
    await _storage.delete(key: _keyPkceNonce);
  }

  Future<void> saveBlindSession({
    required String blindAccessToken,
    String? blindUserId,
    String? blindUserName,
    String? familyDisplayName,
    String? deviceLabel,
    DateTime? linkedAt,
  }) async {
    await _storage.write(key: _keyBlindAccessToken, value: blindAccessToken);
    await saveBlindProfile(
      blindUserId: blindUserId,
      blindUserName: blindUserName,
      familyDisplayName: familyDisplayName,
      deviceLabel: deviceLabel,
      linkedAt: linkedAt,
    );
  }

  Future<void> saveBlindProfile({
    String? blindUserId,
    String? blindUserName,
    String? familyDisplayName,
    String? deviceLabel,
    DateTime? linkedAt,
  }) async {
    await _writeOrDelete(_keyBlindUserId, blindUserId);
    await _writeOrDelete(_keyBlindUserName, blindUserName);
    await _writeOrDelete(_keyBlindFamilyDisplayName, familyDisplayName);
    await _writeOrDelete(_keyBlindDeviceLabel, deviceLabel);
    await _writeDateTimeOrDelete(_keyBlindLinkedAt, linkedAt);
  }

  Future<String?> getBlindAccessToken() =>
      _storage.read(key: _keyBlindAccessToken);

  Future<String?> getBlindUserId() => _storage.read(key: _keyBlindUserId);

  Future<String?> getBlindUserName() => _storage.read(key: _keyBlindUserName);

  Future<String?> getBlindFamilyDisplayName() =>
      _storage.read(key: _keyBlindFamilyDisplayName);

  Future<String?> getBlindDeviceLabel() =>
      _storage.read(key: _keyBlindDeviceLabel);

  Future<DateTime?> getBlindLinkedAt() async {
    final value = await _storage.read(key: _keyBlindLinkedAt);
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value)?.toUtc();
  }

  Future<void> clearBlindSession() async {
    await _storage.delete(key: _keyBlindAccessToken);
    await _storage.delete(key: _keyBlindUserId);
    await _storage.delete(key: _keyBlindUserName);
    await _storage.delete(key: _keyBlindFamilyDisplayName);
    await _storage.delete(key: _keyBlindDeviceLabel);
    await _storage.delete(key: _keyBlindLinkedAt);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyIdToken);
    await _storage.delete(key: _keyExpiresAt);
    await _storage.delete(key: _keyFamilyLoginMethod);
    await clearPendingPkce();
  }

  Future<void> _writeOrDelete(String key, String? value) {
    if (value != null && value.trim().isNotEmpty) {
      return _storage.write(key: key, value: value.trim());
    }
    return _storage.delete(key: key);
  }

  Future<void> _writeDateTimeOrDelete(String key, DateTime? value) {
    if (value != null) {
      return _storage.write(key: key, value: value.toUtc().toIso8601String());
    }
    return _storage.delete(key: key);
  }
}
