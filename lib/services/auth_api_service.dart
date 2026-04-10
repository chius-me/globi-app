import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/auth_config.dart';
import '../models/auth_tokens.dart';
import '../models/current_user.dart';
import '../models/family_login_method.dart';
import '../models/family_profile_bootstrap.dart';
import '../models/local_auth_registration_result.dart';

class AuthApiService {
  final Dio _publicDio;
  final Dio? _protectedDio;

  AuthApiService({Dio? dio, Dio? protectedDio})
    : _publicDio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.backendBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
            ),
          ),
      _protectedDio = protectedDio;

  Future<AuthConfig> getConfig() async {
    final response = await _publicDio.get('/api/auth/config');
    return AuthConfig.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> getAuthorizeUrl({
    required String redirectUri,
    required String state,
    required String codeChallenge,
    required String codeChallengeMethod,
    required String scope,
    required String nonce,
    String? prompt,
  }) async {
    final response = await _publicDio.post(
      '/api/auth/authorize-url',
      data: {
        'redirect_uri': redirectUri,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': codeChallengeMethod,
        'scope': scope,
        'nonce': nonce,
        'prompt': prompt,
      },
    );
    return (response.data as Map<String, dynamic>)['authorization_url']
        as String;
  }

  Future<AuthTokens> exchangeToken({
    required String code,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final response = await _publicDio.post(
      '/api/auth/token',
      data: {
        'code': code,
        'redirect_uri': redirectUri,
        'code_verifier': codeVerifier,
      },
    );
    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthTokens> refreshToken({required String refreshToken}) async {
    return refreshFamilyToken(
      refreshToken: refreshToken,
      loginMethod: FamilyLoginMethod.oidc,
    );
  }

  Future<AuthTokens> refreshFamilyToken({
    required String refreshToken,
    required FamilyLoginMethod loginMethod,
  }) async {
    final path = switch (loginMethod) {
      FamilyLoginMethod.oidc => '/api/auth/refresh',
      FamilyLoginMethod.local => '/api/auth/local/refresh',
    };

    final response = await _publicDio.post(
      path,
      data: {'refresh_token': refreshToken},
    );
    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> logout({
    String? refreshToken,
    String? idToken,
    String? postLogoutRedirectUri,
  }) async {
    final response = await _publicDio.post(
      '/api/auth/logout',
      data: {
        'refresh_token': refreshToken,
        'id_token': idToken,
        'post_logout_redirect_uri':
            postLogoutRedirectUri != null && postLogoutRedirectUri.isNotEmpty
            ? postLogoutRedirectUri
            : null,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> logoutLocal({required String refreshToken}) async {
    await _publicDio.post(
      '/api/auth/local/logout',
      data: {'refresh_token': refreshToken},
    );
  }

  Future<LocalAuthRegistrationResult> registerLocalAccount({
    required String email,
    required String password,
  }) async {
    final response = await _publicDio.post(
      '/api/auth/local/register',
      data: {'email': email.trim(), 'password': password},
    );
    return LocalAuthRegistrationResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> verifyLocalEmail({
    required String email,
    required String code,
  }) async {
    await _publicDio.post(
      '/api/auth/local/verify-email',
      data: {'email': email.trim(), 'code': code.trim()},
    );
  }

  Future<void> resendLocalVerificationCode({required String email}) async {
    await _publicDio.post(
      '/api/auth/local/resend-verification-code',
      data: {'email': email.trim()},
    );
  }

  Future<AuthTokens> loginWithLocalAccount({
    required String email,
    required String password,
  }) async {
    final response = await _publicDio.post(
      '/api/auth/local/login',
      data: {'email': email.trim(), 'password': password},
    );
    return AuthTokens.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> forgotLocalPassword({required String email}) async {
    await _publicDio.post(
      '/api/auth/local/forgot-password',
      data: {'email': email.trim()},
    );
  }

  Future<void> resetLocalPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _publicDio.post(
      '/api/auth/local/reset-password',
      data: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
  }

  Future<void> changeLocalPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    await dio.post(
      '/api/auth/local/change-password',
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
  }

  Future<CurrentUser> getMe({required String accessToken}) async {
    final response = await _publicDio.get(
      '/api/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
    return CurrentUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getPrivateData() async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get('/api/private');
    return response.data as Map<String, dynamic>;
  }

  Future<FamilyProfileBootstrap> getFamilyProfileBootstrap() async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get('/api/family/profile/bootstrap');
    return FamilyProfileBootstrap.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<void> saveFamilyProfile({
    required String email,
    required String phone,
    required String name,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    await dio.post(
      '/api/family/profile',
      data: {'email': email.trim(), 'phone': phone.trim(), 'name': name.trim()},
    );
  }
}
