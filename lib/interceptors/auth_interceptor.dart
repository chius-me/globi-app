import 'dart:async';
import 'package:dio/dio.dart';
import '../services/secure_storage_service.dart';
import '../services/auth_api_service.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;
  final AuthApiService _authApi;
  final FutureOr<void> Function() _onAuthFailure;
  final Dio _dio;

  Completer<AuthTokensRefreshResult>? _refreshCompleter;

  AuthInterceptor({
    required SecureStorageService storage,
    required AuthApiService authApi,
    required FutureOr<void> Function() onAuthFailure,
    required Dio dio,
  }) : _storage = storage,
       _authApi = authApi,
       _onAuthFailure = onAuthFailure,
       _dio = dio;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final accessToken = await _storage.getAccessToken();
    if (accessToken != null) {
      final expiresAt = await _storage.getExpiresAt();
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (expiresAt != null && now >= (expiresAt - 60)) {
        final result = await _tryRefresh();
        if (result.success && result.accessToken != null) {
          options.headers['Authorization'] = 'Bearer ${result.accessToken}';
        } else {
          unawaited(Future<void>.sync(_onAuthFailure));
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'Token refresh failed',
            ),
          );
          return;
        }
      } else {
        options.headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 && err.requestOptions.extra['auth_retry'] != true) {
      final result = await _tryRefresh();
      if (result.success && result.accessToken != null) {
        final opts = err.requestOptions;
        opts.extra['auth_retry'] = true;
        opts.headers['Authorization'] = 'Bearer ${result.accessToken}';
        try {
          final response = await _dio.fetch<dynamic>(opts);
          handler.resolve(response);
          return;
        } catch (e) {
          handler.reject(err);
          return;
        }
      } else {
        unawaited(Future<void>.sync(_onAuthFailure));
      }
    }
    handler.next(err);
  }

  Future<AuthTokensRefreshResult> _tryRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<AuthTokensRefreshResult>();
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) {
        final result = AuthTokensRefreshResult(success: false);
        _refreshCompleter!.complete(result);
        return result;
      }

      final tokens = await _authApi.refreshToken(refreshToken: refreshToken);
      await _storage.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        idToken: tokens.idToken,
        expiresAt: tokens.expiresAt,
      );
      final result = AuthTokensRefreshResult(
        success: true,
        accessToken: tokens.accessToken,
      );
      _refreshCompleter!.complete(result);
      return result;
    } catch (_) {
      final result = AuthTokensRefreshResult(success: false);
      _refreshCompleter!.complete(result);
      return result;
    } finally {
      _refreshCompleter = null;
    }
  }
}

class AuthTokensRefreshResult {
  final bool success;
  final String? accessToken;

  AuthTokensRefreshResult({required this.success, this.accessToken});
}
