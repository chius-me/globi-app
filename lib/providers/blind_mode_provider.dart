import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/blind_identity.dart';
import '../models/blind_link_result.dart';
import '../models/blind_location.dart';
import '../models/blind_location_upload_result.dart';
import '../services/blind_link_api_service.dart';
import '../services/location_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/api_error.dart';

enum BlindSessionStatus { unknown, unlinked, restoreFailed, linked }

class BlindModeProvider extends ChangeNotifier {
  static const Duration locationUploadInterval = Duration(seconds: 45);

  final BlindLinkApiService _blindApi;
  final SecureStorageService _storage;
  final LocationService _locationService;

  BlindSessionStatus _status = BlindSessionStatus.unknown;
  BlindIdentity? _blindIdentity;
  BlindLocation? _lastUploadedLocation;
  BlindLocationUploadResult? _lastUploadResult;
  String? _errorMessage;
  bool _isLinking = false;
  bool _isRefreshingIdentity = false;
  bool _isUploadingLocation = false;
  bool _trackingEnabled = false;
  Timer? _uploadTimer;
  Future<void>? _initializeFuture;

  BlindModeProvider({
    required BlindLinkApiService blindApi,
    required SecureStorageService storage,
    required LocationService locationService,
  }) : _blindApi = blindApi,
       _storage = storage,
       _locationService = locationService;

  BlindSessionStatus get status => _status;
  BlindIdentity? get blindIdentity => _blindIdentity;
  BlindLocation? get lastUploadedLocation => _lastUploadedLocation;
  BlindLocationUploadResult? get lastUploadResult => _lastUploadResult;
  String? get errorMessage => _errorMessage;
  bool get isLinking => _isLinking;
  bool get isRefreshingIdentity => _isRefreshingIdentity;
  bool get isUploadingLocation => _isUploadingLocation;
  bool get isLinked => _status == BlindSessionStatus.linked;

  Future<void> initialize() {
    return _initializeFuture ??= _restoreBlindSession();
  }

  Future<void> _restoreBlindSession() async {
    final blindAccessToken = await _storage.getBlindAccessToken();
    if (blindAccessToken == null || blindAccessToken.isEmpty) {
      _status = BlindSessionStatus.unlinked;
      _blindIdentity = null;
      _lastUploadedLocation = null;
      _lastUploadResult = null;
      _errorMessage = null;
      notifyListeners();
      _initializeFuture = null;
      return;
    }

    _status = BlindSessionStatus.unknown;
    _isRefreshingIdentity = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _hydrateBlindIdentity(blindAccessToken: blindAccessToken);
      _status = BlindSessionStatus.linked;
    } catch (error) {
      await _handleBlindSessionError(error, fallback: '无法验证盲人身份，请检查网络后重试。');
    } finally {
      _isRefreshingIdentity = false;
      _initializeFuture = null;
      notifyListeners();
    }
  }

  Future<void> refreshBlindIdentity() async {
    final blindAccessToken = await _storage.getBlindAccessToken();
    if (blindAccessToken == null || blindAccessToken.isEmpty) {
      await _clearBlindAuthorization();
      return;
    }

    _isRefreshingIdentity = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _hydrateBlindIdentity(blindAccessToken: blindAccessToken);
      _status = BlindSessionStatus.linked;
    } catch (error) {
      await _handleBlindSessionError(error, fallback: '无法刷新盲人身份，请检查网络后重试。');
    } finally {
      _isRefreshingIdentity = false;
      notifyListeners();
    }
  }

  Future<bool> redeemBlindLinkCode({
    required String authorizationCode,
    String? deviceLabel,
  }) async {
    final trimmedCode = authorizationCode.trim();
    if (trimmedCode.isEmpty || _isLinking) {
      return false;
    }

    _isLinking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _blindApi.redeemBlindLinkCode(
        authorizationCode: trimmedCode,
        deviceLabel: deviceLabel,
      );

      await _persistBlindLinkResult(result);
      _blindIdentity = BlindIdentity(
        blindUserId: result.blindUserId,
        blindUserName: result.blindUserName,
        familyDisplayName: result.familyDisplayName,
        deviceLabel: result.deviceLabel,
        linkedAt: result.linkedAt,
        lastSeenAt: null,
        lastLocationAt: null,
      );
      _status = BlindSessionStatus.linked;
      _lastUploadedLocation = null;
      _lastUploadResult = null;
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(
        error,
        fallback: '绑定失败，请检查授权码后重试。',
      );
      return false;
    } finally {
      _isLinking = false;
      notifyListeners();
    }
  }

  Future<void> clearBlindAuthorization() {
    return _clearBlindAuthorization();
  }

  Future<void> startForegroundTracking() async {
    if (!isLinked || _trackingEnabled) {
      return;
    }

    _trackingEnabled = true;
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(locationUploadInterval, (_) {
      unawaited(uploadCurrentLocation());
    });

    await uploadCurrentLocation(silentErrors: _lastUploadedLocation != null);
  }

  void stopForegroundTracking() {
    _trackingEnabled = false;
    _uploadTimer?.cancel();
    _uploadTimer = null;
  }

  Future<void> uploadCurrentLocation({bool silentErrors = true}) async {
    if (!isLinked || _isUploadingLocation) {
      return;
    }

    final blindAccessToken = await _storage.getBlindAccessToken();
    if (blindAccessToken == null || blindAccessToken.isEmpty) {
      await _clearBlindAuthorization();
      return;
    }

    _isUploadingLocation = true;
    if (!silentErrors) {
      _errorMessage = null;
    }
    notifyListeners();

    try {
      final position = await _locationService.getCurrentPosition();
      final location = BlindLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyMeters: _finiteDouble(position.accuracy),
        altitudeMeters: _finiteDouble(position.altitude),
        speedMps: _finiteDouble(position.speed),
        headingDegrees: _finiteDouble(position.heading),
        provider: 'geolocator',
        capturedAt: position.timestamp.toUtc(),
      );

      final result = await _blindApi.uploadBlindLocation(
        blindAccessToken: blindAccessToken,
        location: location,
      );

      _lastUploadResult = result;
      _lastUploadedLocation = location.copyWith(
        updatedAt: result.updatedAt ?? result.recordedAt,
      );
      _errorMessage = null;
    } catch (error) {
      if (isUnauthorizedError(error)) {
        await _clearBlindAuthorization(errorMessage: '盲人授权已失效，请重新输入授权码。');
      } else {
        final message = error is LocationServiceException
            ? error.message
            : resolveApiErrorMessage(error, fallback: '定位上传失败，请稍后再试。');
        if (!silentErrors || _lastUploadedLocation == null) {
          _errorMessage = message;
        }
      }
    } finally {
      _isUploadingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> openLocationSettings() {
    return _locationService.openLocationSettings();
  }

  Future<bool> openAppSettings() {
    return _locationService.openAppSettings();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _hydrateBlindIdentity({required String blindAccessToken}) async {
    final blindIdentity = await _blindApi.getBlindMe(
      blindAccessToken: blindAccessToken,
    );
    _blindIdentity = blindIdentity;
    await _storage.saveBlindProfile(
      blindUserId: blindIdentity.blindUserId,
      blindUserName: blindIdentity.blindUserName,
      familyDisplayName: blindIdentity.familyDisplayName,
      deviceLabel: blindIdentity.deviceLabel,
      linkedAt: blindIdentity.linkedAt,
    );
  }

  Future<void> _persistBlindLinkResult(BlindLinkResult result) {
    return _storage.saveBlindSession(
      blindAccessToken: result.blindAccessToken,
      blindUserId: result.blindUserId,
      blindUserName: result.blindUserName,
      familyDisplayName: result.familyDisplayName,
      deviceLabel: result.deviceLabel,
      linkedAt: result.linkedAt,
    );
  }

  Future<void> _handleBlindSessionError(
    Object error, {
    required String fallback,
  }) async {
    if (isUnauthorizedError(error)) {
      await _clearBlindAuthorization(errorMessage: '盲人授权已失效，请重新输入授权码。');
      return;
    }

    _status = BlindSessionStatus.restoreFailed;
    _errorMessage = resolveApiErrorMessage(error, fallback: fallback);
  }

  Future<void> _clearBlindAuthorization({String? errorMessage}) async {
    stopForegroundTracking();
    await _storage.clearBlindSession();
    _blindIdentity = null;
    _lastUploadedLocation = null;
    _lastUploadResult = null;
    _status = BlindSessionStatus.unlinked;
    _errorMessage = errorMessage;
    notifyListeners();
  }

  double? _finiteDouble(double value) {
    if (value.isFinite) {
      return value;
    }
    return null;
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    super.dispose();
  }
}
