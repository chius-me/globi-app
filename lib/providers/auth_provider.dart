import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../models/auth_config.dart';
import '../models/current_user.dart';
import '../models/family_profile.dart';
import '../models/family_profile_bootstrap.dart';
import '../services/auth_api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/api_error.dart';
import '../utils/pkce.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum FamilyProfileStatus { unknown, loading, incomplete, complete, error }

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;
  final SecureStorageService _storage;

  AuthStatus _status = AuthStatus.unknown;
  CurrentUser? _user;
  AuthConfig? _config;
  String? _errorMessage;
  bool _isLoggingIn = false;
  Future<void>? _initializeFuture;
  String? _privateMessage;
  Map<String, dynamic>? _privateUserInfo;
  FamilyProfileBootstrap? _familyProfileBootstrap;
  FamilyProfileStatus _familyProfileStatus = FamilyProfileStatus.unknown;
  String? _familyProfileErrorMessage;
  bool _isSavingFamilyProfile = false;

  // PKCE session state
  Pkce? _pendingPkce;

  AuthStatus get status => _status;
  CurrentUser? get user => _user;
  AuthConfig? get config => _config;
  String? get errorMessage => _errorMessage;
  bool get isLoggingIn => _isLoggingIn;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get privateMessage => _privateMessage;
  Map<String, dynamic>? get privateUserInfo => _privateUserInfo;
  FamilyProfileBootstrap? get familyProfileBootstrap => _familyProfileBootstrap;
  FamilyProfileStatus get familyProfileStatus => _familyProfileStatus;
  String? get familyProfileErrorMessage => _familyProfileErrorMessage;
  bool get isSavingFamilyProfile => _isSavingFamilyProfile;
  bool get isLoadingFamilyProfile =>
      _familyProfileStatus == FamilyProfileStatus.loading;
  bool get isFamilyProfileCompleted =>
      _familyProfileStatus == FamilyProfileStatus.complete;

  AuthProvider({
    required AuthApiService authApi,
    required SecureStorageService storage,
  }) : _authApi = authApi,
       _storage = storage;

  Future<void> initialize() {
    return _initializeFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      _config = await _authApi.getConfig();
    } catch (_) {
      // Config fetch failed; continue, login will fail later
    }

    try {
      final pendingPkce = await _loadPendingPkce();
      if (pendingPkce != null) {
        _pendingPkce = pendingPkce;
        _isLoggingIn = true;
      }

      // Try to restore session from stored tokens
      final accessToken = await _storage.getAccessToken();
      final expiresAt = await _storage.getExpiresAt();

      if (accessToken != null && expiresAt != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if (now < expiresAt) {
          // Token still valid, fetch user info
          try {
            await _hydrateAuthenticatedSession(accessToken: accessToken);
            return;
          } catch (_) {
            // Try refresh
            final refreshed = await _tryRefreshAndGetMe();
            if (refreshed) return;
          }
        } else {
          // Token expired, try refresh
          final refreshed = await _tryRefreshAndGetMe();
          if (refreshed) return;
        }
      }

      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } finally {
      _initializeFuture = null;
    }
  }

  Future<Pkce?> _loadPendingPkce() async {
    final pending = await _storage.getPendingPkce();
    if (pending == null) {
      return null;
    }

    return Pkce.fromStored(
      codeVerifier: pending['code_verifier']!,
      codeChallenge: pending['code_challenge']!,
      state: pending['state']!,
      nonce: pending['nonce']!,
    );
  }

  Future<bool> _tryRefreshAndGetMe() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final tokens = await _authApi.refreshToken(refreshToken: refreshToken);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        idToken: tokens.idToken,
        expiresAt: tokens.expiresAt,
      );
      await _hydrateAuthenticatedSession(accessToken: tokens.accessToken);
      return true;
    } catch (_) {
      await _storage.clearAll();
      _privateMessage = null;
      _privateUserInfo = null;
      return false;
    }
  }

  Future<void> _hydrateAuthenticatedSession({
    required String accessToken,
  }) async {
    _user = await _authApi.getMe(accessToken: accessToken);

    try {
      final privateData = await _authApi.getPrivateData();
      _privateMessage = privateData['message'] as String?;
      _privateUserInfo = privateData['user_info'] as Map<String, dynamic>?;
    } catch (_) {
      _privateMessage = null;
      _privateUserInfo = null;
    }

    await _loadFamilyProfileBootstrap();

    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> _loadFamilyProfileBootstrap() async {
    _familyProfileStatus = FamilyProfileStatus.loading;
    _familyProfileErrorMessage = null;

    try {
      final bootstrap = await _authApi.getFamilyProfileBootstrap();
      _familyProfileBootstrap = bootstrap;
      _familyProfileStatus = bootstrap.profileCompleted
          ? FamilyProfileStatus.complete
          : FamilyProfileStatus.incomplete;
    } catch (error) {
      _familyProfileBootstrap = null;
      _familyProfileStatus = FamilyProfileStatus.error;
      _familyProfileErrorMessage = resolveApiErrorMessage(
        error,
        fallback: '家属资料状态加载失败，请重试。',
      );
    }
  }

  Future<void> refreshFamilyProfileBootstrap() async {
    if (_status != AuthStatus.authenticated) {
      return;
    }

    _familyProfileStatus = FamilyProfileStatus.loading;
    _familyProfileErrorMessage = null;
    notifyListeners();

    await _loadFamilyProfileBootstrap();
    notifyListeners();
  }

  Future<bool> saveFamilyProfile({
    required String email,
    required String phone,
    required String name,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPhone = phone.trim();
    final trimmedName = name.trim();

    if (trimmedEmail.isEmpty ||
        trimmedPhone.isEmpty ||
        trimmedName.isEmpty ||
        _isSavingFamilyProfile) {
      _familyProfileErrorMessage = '请完整填写邮箱、电话和姓名。';
      notifyListeners();
      return false;
    }

    _isSavingFamilyProfile = true;
    _familyProfileErrorMessage = null;
    notifyListeners();

    try {
      await _authApi.saveFamilyProfile(
        email: trimmedEmail,
        phone: trimmedPhone,
        name: trimmedName,
      );
      _familyProfileBootstrap = FamilyProfileBootstrap(
        profileCompleted: true,
        suggestedEmail: trimmedEmail,
        suggestedName: trimmedName,
        profile: FamilyProfile(
          email: trimmedEmail,
          phone: trimmedPhone,
          name: trimmedName,
        ),
      );
      _familyProfileStatus = FamilyProfileStatus.complete;
      return true;
    } catch (error) {
      _familyProfileErrorMessage = resolveApiErrorMessage(
        error,
        fallback: '家属资料保存失败，请稍后重试。',
      );
      return false;
    } finally {
      _isSavingFamilyProfile = false;
      notifyListeners();
    }
  }

  Future<void> refreshAuthenticatedSession() async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null) {
      await forceUnauthenticated();
      return;
    }

    try {
      await _hydrateAuthenticatedSession(accessToken: accessToken);
    } catch (_) {
      final refreshed = await _tryRefreshAndGetMe();
      if (!refreshed) {
        await forceUnauthenticated();
      }
    }
  }

  Future<void> startLogin() async {
    _errorMessage = null;
    _isLoggingIn = true;
    notifyListeners();

    try {
      _config ??= await _authApi.getConfig();

      final pkce = Pkce.generate();
      _pendingPkce = pkce;
      await _storage.savePendingPkce(
        codeVerifier: pkce.codeVerifier,
        codeChallenge: pkce.codeChallenge,
        state: pkce.state,
        nonce: pkce.nonce,
      );

      final authUrl = await _authApi.getAuthorizeUrl(
        redirectUri: AppConstants.redirectUri,
        state: pkce.state,
        codeChallenge: pkce.codeChallenge,
        codeChallengeMethod: 'S256',
        scope: _config!.scopes.join(' '),
        nonce: pkce.nonce,
        prompt: 'login',
      );

      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _errorMessage = '无法打开浏览器';
        _isLoggingIn = false;
        await _storage.clearPendingPkce();
        _pendingPkce = null;
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = '登录初始化失败: $e';
      _isLoggingIn = false;
      await _storage.clearPendingPkce();
      _pendingPkce = null;
      notifyListeners();
    }
  }

  Future<void> handleCallback(Uri uri) async {
    await initialize();
    _errorMessage = null;

    final error = uri.queryParameters['error'];
    if (error != null) {
      final desc = uri.queryParameters['error_description'] ?? error;
      _errorMessage = '登录失败: $desc';
      _isLoggingIn = false;
      _pendingPkce = null;
      _status = AuthStatus.unauthenticated;
      await _storage.clearPendingPkce();
      notifyListeners();
      return;
    }

    final code = uri.queryParameters['code'];
    final returnedState = uri.queryParameters['state'];

    if (code == null || returnedState == null) {
      _errorMessage = '无效的回调参数';
      _isLoggingIn = false;
      _pendingPkce = null;
      _status = AuthStatus.unauthenticated;
      await _storage.clearPendingPkce();
      notifyListeners();
      return;
    }

    if (_pendingPkce == null || returnedState != _pendingPkce!.state) {
      _errorMessage = 'State 校验失败，可能存在安全风险';
      _isLoggingIn = false;
      _pendingPkce = null;
      _status = AuthStatus.unauthenticated;
      await _storage.clearPendingPkce();
      notifyListeners();
      return;
    }

    try {
      final tokens = await _authApi.exchangeToken(
        code: code,
        redirectUri: AppConstants.redirectUri,
        codeVerifier: _pendingPkce!.codeVerifier,
      );

      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        idToken: tokens.idToken,
        expiresAt: tokens.expiresAt,
      );

      await _hydrateAuthenticatedSession(accessToken: tokens.accessToken);
      await _storage.clearPendingPkce();
    } catch (e) {
      _errorMessage = '登录完成失败: $e';
      _status = AuthStatus.unauthenticated;
      await _storage.clearAll();
    } finally {
      _isLoggingIn = false;
      _pendingPkce = null;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      final idToken = await _storage.getIdToken();

      final result = await _authApi.logout(
        refreshToken: refreshToken,
        idToken: idToken,
        postLogoutRedirectUri: AppConstants.postLogoutRedirectUri.isNotEmpty
            ? AppConstants.postLogoutRedirectUri
            : null,
      );

      final endSessionUrl = result['end_session_url'] as String?;
      if (endSessionUrl != null && endSessionUrl.isNotEmpty) {
        final uri = Uri.parse(endSessionUrl);
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          _errorMessage = '无法打开退出登录页面';
          notifyListeners();
        }
      }
    } catch (_) {
      // Logout API failed, still clear local session
    } finally {
      await _storage.clearAll();
      _user = null;
      _privateMessage = null;
      _privateUserInfo = null;
      _familyProfileBootstrap = null;
      _familyProfileStatus = FamilyProfileStatus.unknown;
      _familyProfileErrorMessage = null;
      _isSavingFamilyProfile = false;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> forceUnauthenticated() async {
    await _storage.clearAll();
    _user = null;
    _privateMessage = null;
    _privateUserInfo = null;
    _familyProfileBootstrap = null;
    _familyProfileStatus = FamilyProfileStatus.unknown;
    _familyProfileErrorMessage = null;
    _isSavingFamilyProfile = false;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    _isLoggingIn = false;
    _pendingPkce = null;
    _initializeFuture = null;
    notifyListeners();
  }
}
