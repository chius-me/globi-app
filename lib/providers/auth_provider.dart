import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/auth_tokens.dart';
import '../models/current_user.dart';
import '../models/family_login_method.dart';
import '../models/family_profile.dart';
import '../models/family_profile_bootstrap.dart';
import '../models/local_auth_registration_result.dart';
import '../services/auth_api_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/api_error.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum FamilyProfileStatus { unknown, loading, incomplete, complete, error }

enum LocalAuthAction {
  login,
  register,
  verifyEmail,
  resendVerification,
  forgotPassword,
  resetPassword,
  changePassword,
}

class AuthProvider extends ChangeNotifier {
  final AuthApiService _authApi;
  final SecureStorageService _storage;

  AuthStatus _status = AuthStatus.unknown;
  CurrentUser? _user;
  String? _errorMessage;
  bool _isLoggingIn = false;
  Future<void>? _initializeFuture;
  String? _privateMessage;
  Map<String, dynamic>? _privateUserInfo;
  FamilyProfileBootstrap? _familyProfileBootstrap;
  FamilyProfileStatus _familyProfileStatus = FamilyProfileStatus.unknown;
  String? _familyProfileErrorMessage;
  bool _isSavingFamilyProfile = false;
  FamilyLoginMethod? _familyLoginMethod;
  LocalAuthAction? _activeLocalAuthAction;

  AuthStatus get status => _status;
  CurrentUser? get user => _user;
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
  FamilyLoginMethod? get familyLoginMethod => _familyLoginMethod;
  bool get isLocalLogin => _familyLoginMethod == FamilyLoginMethod.local;
  bool get isLocalAuthBusy => _activeLocalAuthAction != null;

  AuthProvider({
    required AuthApiService authApi,
    required SecureStorageService storage,
  }) : _authApi = authApi,
       _storage = storage;

  bool isLocalAuthActionInProgress(LocalAuthAction action) {
    return _activeLocalAuthAction == action;
  }

  Future<void> initialize() {
    return _initializeFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      _familyLoginMethod = await _storage.getFamilyLoginMethod();

      final accessToken = await _storage.getAccessToken();
      final expiresAt = await _storage.getExpiresAt();

      if (accessToken != null && _familyLoginMethod != null) {
        if (expiresAt != null) {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (now < expiresAt) {
            try {
              await _hydrateAuthenticatedSession(accessToken: accessToken);
              return;
            } catch (_) {
              final refreshed = await _tryRefreshAndGetMe();
              if (refreshed) {
                return;
              }
            }
          } else {
            final refreshed = await _tryRefreshAndGetMe();
            if (refreshed) {
              return;
            }
          }
        } else {
          final refreshed = await _tryRefreshAndGetMe();
          if (refreshed) {
            return;
          }
        }
      }

      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } finally {
      _initializeFuture = null;
    }
  }

  Future<FamilyLoginMethod?> _resolveStoredLoginMethod() async {
    if (_familyLoginMethod != null) {
      return _familyLoginMethod;
    }

    final stored = await _storage.getFamilyLoginMethod();
    if (stored != null) {
      _familyLoginMethod = stored;
      return stored;
    }

    return null;
  }

  Future<void> _persistFamilyTokens({
    required AuthTokens tokens,
    required FamilyLoginMethod loginMethod,
  }) async {
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
    );
    await _storage.saveFamilyLoginMethod(loginMethod);
    _familyLoginMethod = loginMethod;
  }

  Future<void> _syncFamilyLoginMethodWithUser() async {
    final inferred = familyLoginMethodFromUserSource(_user?.source);
    if (inferred == null || inferred == _familyLoginMethod) {
      return;
    }

    _familyLoginMethod = inferred;
    await _storage.saveFamilyLoginMethod(inferred);
  }

  Future<void> _completeAuthenticatedLogin({
    required AuthTokens tokens,
    required FamilyLoginMethod loginMethod,
  }) async {
    await _persistFamilyTokens(tokens: tokens, loginMethod: loginMethod);

    try {
      await _hydrateAuthenticatedSession(accessToken: tokens.accessToken);
    } catch (_) {
      await _resetSessionState(clearErrorMessage: false);
      rethrow;
    }
  }

  Future<bool> _tryRefreshAndGetMe() async {
    final refreshToken = await _storage.getRefreshToken();
    final loginMethod = await _resolveStoredLoginMethod();
    if (refreshToken == null || loginMethod == null) {
      return false;
    }

    try {
      final tokens = await _authApi.refreshFamilyToken(
        refreshToken: refreshToken,
        loginMethod: loginMethod,
      );
      await _persistFamilyTokens(tokens: tokens, loginMethod: loginMethod);
      await _hydrateAuthenticatedSession(accessToken: tokens.accessToken);
      return true;
    } catch (_) {
      await _resetSessionState();
      return false;
    }
  }

  Future<void> _hydrateAuthenticatedSession({
    required String accessToken,
  }) async {
    _user = await _authApi.getMe(accessToken: accessToken);
    await _syncFamilyLoginMethodWithUser();

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

    await _resolveStoredLoginMethod();

    try {
      await _hydrateAuthenticatedSession(accessToken: accessToken);
    } catch (_) {
      final refreshed = await _tryRefreshAndGetMe();
      if (!refreshed) {
        await forceUnauthenticated();
      }
    }
  }

  Future<T?> _runLocalAuthAction<T>({
    required LocalAuthAction action,
    required String fallbackMessage,
    required Future<T> Function() task,
  }) async {
    if (_activeLocalAuthAction != null) {
      return null;
    }

    _errorMessage = null;
    _activeLocalAuthAction = action;
    notifyListeners();

    try {
      return await task();
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(error, fallback: fallbackMessage);
      return null;
    } finally {
      _activeLocalAuthAction = null;
      notifyListeners();
    }
  }

  Future<LocalAuthRegistrationResult?> registerLocalAccount({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _errorMessage = '请输入邮箱和密码。';
      notifyListeners();
      return null;
    }

    return _runLocalAuthAction<LocalAuthRegistrationResult>(
      action: LocalAuthAction.register,
      fallbackMessage: '注册失败，请稍后重试。',
      task: () {
        return _authApi.registerLocalAccount(
          email: trimmedEmail,
          password: password,
        );
      },
    );
  }

  Future<bool> verifyLocalEmail({
    required String email,
    required String code,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedCode = code.trim();
    if (trimmedEmail.isEmpty || trimmedCode.isEmpty) {
      _errorMessage = '请输入邮箱和验证码。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.verifyEmail,
      fallbackMessage: '邮箱验证失败，请重新输入验证码。',
      task: () async {
        await _authApi.verifyLocalEmail(email: trimmedEmail, code: trimmedCode);
        return true;
      },
    );
    return result ?? false;
  }

  Future<bool> resendLocalVerificationCode({required String email}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      _errorMessage = '请输入邮箱。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.resendVerification,
      fallbackMessage: '验证码发送失败，请稍后重试。',
      task: () async {
        await _authApi.resendLocalVerificationCode(email: trimmedEmail);
        return true;
      },
    );
    return result ?? false;
  }

  Future<bool> loginWithLocalAccount({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || password.isEmpty) {
      _errorMessage = '请输入邮箱和密码。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.login,
      fallbackMessage: '邮箱登录失败，请稍后重试。',
      task: () async {
        final tokens = await _authApi.loginWithLocalAccount(
          email: trimmedEmail,
          password: password,
        );
        await _completeAuthenticatedLogin(
          tokens: tokens,
          loginMethod: FamilyLoginMethod.local,
        );
        return true;
      },
    );
    return result ?? false;
  }

  Future<bool> sendLocalPasswordResetCode({required String email}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      _errorMessage = '请输入邮箱。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.forgotPassword,
      fallbackMessage: '重置验证码发送失败，请稍后重试。',
      task: () async {
        await _authApi.forgotLocalPassword(email: trimmedEmail);
        return true;
      },
    );
    return result ?? false;
  }

  Future<bool> resetLocalPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedCode = code.trim();
    if (trimmedEmail.isEmpty || trimmedCode.isEmpty || newPassword.isEmpty) {
      _errorMessage = '请完整填写邮箱、验证码和新密码。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.resetPassword,
      fallbackMessage: '密码重置失败，请稍后重试。',
      task: () async {
        await _authApi.resetLocalPassword(
          email: trimmedEmail,
          code: trimmedCode,
          newPassword: newPassword,
        );
        return true;
      },
    );
    return result ?? false;
  }

  Future<bool> changeLocalPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (!isLocalLogin) {
      _errorMessage = '当前账号不是邮箱密码登录，不支持修改密码。';
      notifyListeners();
      return false;
    }

    if (oldPassword.isEmpty || newPassword.isEmpty) {
      _errorMessage = '请输入旧密码和新密码。';
      notifyListeners();
      return false;
    }

    final result = await _runLocalAuthAction<bool>(
      action: LocalAuthAction.changePassword,
      fallbackMessage: '修改密码失败，请稍后重试。',
      task: () async {
        await _authApi.changeLocalPassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
        );
        return true;
      },
    );
    return result ?? false;
  }

  Future<void> startGithubLogin() async {
    _errorMessage = null;
    _isLoggingIn = true;
    notifyListeners();

    try {
      final authUrl = await _authApi.getGithubAuthorizeUrl();

      final uri = Uri.parse(authUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _errorMessage = '无法打开浏览器';
        _isLoggingIn = false;
        notifyListeners();
      }
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(error, fallback: '登录初始化失败，请稍后重试。');
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  void cancelGithubLogin() {
    _isLoggingIn = false;
    notifyListeners();
  }

  Future<void> handleCallback(Uri uri) async {
    await initialize();
    _errorMessage = null;

    final error = uri.queryParameters['error'];
    if (error != null) {
      final desc = uri.queryParameters['error_description'] ?? error;
      _errorMessage = '登录失败: $desc';
      _isLoggingIn = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      _errorMessage = '无效的回调参数';
      _isLoggingIn = false;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      int expiresAt;
      try {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = utf8.decode(
            base64Url.decode(base64Url.normalize(parts[1])),
          );
          final claims = jsonDecode(payload) as Map<String, dynamic>;
          expiresAt = (claims['exp'] as int?) ?? _defaultExpiry();
        } else {
          expiresAt = _defaultExpiry();
        }
      } catch (_) {
        expiresAt = _defaultExpiry();
      }

      final refreshToken = uri.queryParameters['refresh_token'];
      final expiresAtParam = int.tryParse(uri.queryParameters['expires_at'] ?? '');

      final tokens = AuthTokens(
        accessToken: token,
        tokenType: 'Bearer',
        expiresIn:
            (expiresAtParam ?? expiresAt) -
            (DateTime.now().millisecondsSinceEpoch ~/ 1000),
        expiresAt: expiresAtParam ?? expiresAt,
        refreshToken: refreshToken,
      );

      await _completeAuthenticatedLogin(
        tokens: tokens,
        loginMethod: FamilyLoginMethod.github,
      );
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(error, fallback: '登录完成失败，请稍后重试。');
      await _resetSessionState(clearErrorMessage: false);
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  static int _defaultExpiry() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  }

  Future<void> logout() async {
    final loginMethod = await _resolveStoredLoginMethod();

    try {
      final refreshToken = await _storage.getRefreshToken();

      if (loginMethod == FamilyLoginMethod.local) {
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _authApi.logoutLocal(refreshToken: refreshToken);
        }
      } else if (loginMethod == FamilyLoginMethod.github) {
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _authApi.logoutGithub(refreshToken: refreshToken);
        }
      }
    } catch (_) {
      // Logout API failed, still clear local session.
    } finally {
      await _resetSessionState();
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _resetSessionState({
    bool clearStorage = true,
    bool clearErrorMessage = true,
  }) async {
    if (clearStorage) {
      await _storage.clearAll();
    }

    _user = null;
    _privateMessage = null;
    _privateUserInfo = null;
    _familyProfileBootstrap = null;
    _familyProfileStatus = FamilyProfileStatus.unknown;
    _familyProfileErrorMessage = null;
    _isSavingFamilyProfile = false;
    _familyLoginMethod = null;
    _activeLocalAuthAction = null;
    _status = AuthStatus.unauthenticated;
    _isLoggingIn = false;

    if (clearErrorMessage) {
      _errorMessage = null;
    }
  }

  Future<void> forceUnauthenticated() async {
    await _resetSessionState();
    _initializeFuture = null;
    notifyListeners();
  }
}
