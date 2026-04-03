import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/auth_config.dart';
import '../models/auth_tokens.dart';
import '../models/current_user.dart';
import '../models/family_profile_bootstrap.dart';

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
    final response = await _publicDio.post(
      '/api/auth/refresh',
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
