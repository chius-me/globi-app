import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/blind_location.dart';
import '../models/blind_link_code.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_geofence.dart';
import '../models/family_blind_user_map.dart';
import '../models/family_blind_user_location.dart';
import '../models/family_blind_user_route_history.dart';
import '../models/family_sos_event.dart';
import '../services/blind_link_api_service.dart';
import '../services/notification_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/api_error.dart';

class FamilyBlindProvider extends ChangeNotifier {
  final BlindLinkApiService _blindApi;
  final SecureStorageService _storage;
  final NotificationService _notificationService;
  WebSocketChannel? _locationChannel;
  StreamSubscription<dynamic>? _locationSubscription;
  WebSocketChannel? _sosChannel;
  StreamSubscription<dynamic>? _sosSubscription;

  BlindLinkCode? _latestLinkCode;
  List<FamilyBlindUser> _blindUsers = const [];
  List<FamilySosEvent> _activeSosEvents = const [];
  String? _errorMessage;
  bool _isCreatingLinkCode = false;
  bool _isLoadingBlindUsers = false;
  bool _isDeletingBlindUser = false;
  bool _isLoadingSosEvents = false;
  bool _isAcknowledgingSos = false;

  FamilyBlindProvider({
    required BlindLinkApiService blindApi,
    required SecureStorageService storage,
    required NotificationService notificationService,
  }) : _blindApi = blindApi,
       _notificationService = notificationService,
       _storage = storage;

  BlindLinkCode? get latestLinkCode => _latestLinkCode;
  List<FamilyBlindUser> get blindUsers => List.unmodifiable(_blindUsers);
  List<FamilySosEvent> get activeSosEvents =>
      List.unmodifiable(_activeSosEvents);
  String? get errorMessage => _errorMessage;
  bool get isCreatingLinkCode => _isCreatingLinkCode;
  bool get isLoadingBlindUsers => _isLoadingBlindUsers;
  bool get isDeletingBlindUser => _isDeletingBlindUser;
  bool get isLoadingSosEvents => _isLoadingSosEvents;
  bool get isAcknowledgingSos => _isAcknowledgingSos;

  Future<BlindLinkCode?> createBlindLinkCode({
    required String blindUserName,
  }) async {
    final trimmedName = blindUserName.trim();
    if (trimmedName.isEmpty || _isCreatingLinkCode) {
      return null;
    }

    _isCreatingLinkCode = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _blindApi.createBlindLinkCode(
        blindUserName: trimmedName,
      );
      _latestLinkCode = result;
      return result;
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(error, fallback: '授权码生成失败，请稍后再试。');
    } finally {
      _isCreatingLinkCode = false;
      notifyListeners();
    }

    return null;
  }

  Future<void> refreshBlindUsers() async {
    if (_isLoadingBlindUsers) {
      return;
    }

    _isLoadingBlindUsers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _blindUsers = await _blindApi.listFamilyBlindUsers();
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(
        error,
        fallback: '已绑定盲人用户加载失败，请稍后重试。',
      );
    } finally {
      _isLoadingBlindUsers = false;
      notifyListeners();
    }
  }

  Future<FamilyBlindUserLocation> refreshBlindUserLocation(
    String blindUserId,
  ) async {
    final result = await _blindApi.getFamilyBlindUserLocation(
      blindUserId: blindUserId,
    );

    _blindUsers = _blindUsers
        .map((user) {
          if (user.blindUserId != blindUserId) {
            return user;
          }
          return user.copyWith(
            blindUserName: result.blindUserName,
            lastLocationAt:
                result.latestLocation?.updatedAt ??
                result.latestLocation?.capturedAt,
            latestLocation: result.latestLocation,
            clearLatestLocation: result.latestLocation == null,
          );
        })
        .toList(growable: false);
    notifyListeners();

    return result;
  }

  Future<FamilyBlindUserMap> refreshBlindUserMap(String blindUserId) async {
    final result = await _blindApi.getFamilyBlindUserMap(
      blindUserId: blindUserId,
    );

    _blindUsers = _blindUsers
        .map((user) {
          if (user.blindUserId != blindUserId) {
            return user;
          }
          return user.copyWith(
            blindUserName: result.blindUserName,
            lastLocationAt:
                result.latestLocation?.updatedAt ??
                result.latestLocation?.capturedAt,
            latestLocation: result.latestLocation,
            clearLatestLocation: result.latestLocation == null,
          );
        })
        .toList(growable: false);
    notifyListeners();

    return result;
  }

  Future<void> refreshSosEvents() async {
    if (_isLoadingSosEvents) {
      return;
    }

    _isLoadingSosEvents = true;
    notifyListeners();
    try {
      _activeSosEvents = await _blindApi.listFamilySosEvents();
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(
        error,
        fallback: 'SOS 求助加载失败，请稍后重试。',
      );
    } finally {
      _isLoadingSosEvents = false;
      notifyListeners();
    }
  }

  Future<void> refreshHomeData() async {
    await refreshBlindUsers();
    await refreshSosEvents();
  }

  Future<bool> acknowledgeSosEvent(String sosEventId) async {
    if (_isAcknowledgingSos) {
      return false;
    }

    _isAcknowledgingSos = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _blindApi.acknowledgeFamilySosEvent(sosEventId: sosEventId);
      _activeSosEvents = _activeSosEvents
          .where((event) => event.sosEventId != sosEventId)
          .toList(growable: false);
      return true;
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(
        error,
        fallback: 'SOS 确认失败，请稍后重试。',
      );
      return false;
    } finally {
      _isAcknowledgingSos = false;
      notifyListeners();
    }
  }

  Future<List<FamilySosEvent>> getSosHistory() {
    return _blindApi.listFamilySosEvents(status: 'all', limit: 100);
  }

  Future<FamilyBlindUserRouteHistory> getBlindUserRouteHistory(
    String blindUserId, {
    int hours = 24,
  }) {
    return _blindApi.getFamilyBlindUserRouteHistory(
      blindUserId: blindUserId,
      hours: hours,
    );
  }

  Future<List<FamilyBlindUserGeofence>> listBlindUserGeofences(
    String blindUserId,
  ) {
    return _blindApi.listFamilyBlindUserGeofences(blindUserId: blindUserId);
  }

  Future<FamilyBlindUserGeofence> createBlindUserGeofence({
    required String blindUserId,
    required String label,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    return _blindApi.createFamilyBlindUserGeofence(
      blindUserId: blindUserId,
      label: label,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  Future<bool> deleteBlindUserGeofence({
    required String blindUserId,
    required String geofenceId,
  }) {
    return _blindApi.deleteFamilyBlindUserGeofence(
      blindUserId: blindUserId,
      geofenceId: geofenceId,
    );
  }

  Future<void> connectLocationUpdates(String blindUserId) async {
    await disconnectLocationUpdates();
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    final uri = _blindApi.familyLocationWebSocketUri(
      blindUserId: blindUserId,
      accessToken: accessToken,
    );
    final channel = WebSocketChannel.connect(uri);
    _locationChannel = channel;
    _locationSubscription = channel.stream.listen(
      (message) => _handleLocationEvent(blindUserId, message),
      onError: (_) {},
      onDone: () {},
    );
  }

  Future<void> disconnectLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
    await _locationChannel?.sink.close();
    _locationChannel = null;
  }

  Future<void> connectSosUpdates() async {
    await disconnectSosUpdates();
    final accessToken = await _storage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    final channel = WebSocketChannel.connect(
      _blindApi.familySosWebSocketUri(accessToken: accessToken),
    );
    _sosChannel = channel;
    _sosSubscription = channel.stream.listen(
      _handleSosEvent,
      onError: (_) {},
      onDone: () {},
    );
  }

  Future<void> disconnectSosUpdates() async {
    await _sosSubscription?.cancel();
    _sosSubscription = null;
    await _sosChannel?.sink.close();
    _sosChannel = null;
  }

  Future<bool> deleteBlindUser(String blindUserId) async {
    if (_isDeletingBlindUser) {
      return false;
    }

    _isDeletingBlindUser = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deleted = await _blindApi.deleteFamilyBlindUser(
        blindUserId: blindUserId,
      );
      if (deleted) {
        _blindUsers = _blindUsers
            .where((user) => user.blindUserId != blindUserId)
            .toList(growable: false);
      }
      return deleted;
    } catch (error) {
      _errorMessage = resolveApiErrorMessage(error, fallback: '删除绑定失败，请稍后重试。');
      return false;
    } finally {
      _isDeletingBlindUser = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  void clearState() {
    unawaited(disconnectLocationUpdates());
    unawaited(disconnectSosUpdates());
    _latestLinkCode = null;
    _blindUsers = const [];
    _activeSosEvents = const [];
    _errorMessage = null;
    _isCreatingLinkCode = false;
    _isLoadingBlindUsers = false;
    _isDeletingBlindUser = false;
    _isLoadingSosEvents = false;
    _isAcknowledgingSos = false;
    notifyListeners();
  }

  void _handleLocationEvent(String blindUserId, dynamic message) {
    if (message is! String) return;
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) return;
    final locationJson = decoded['location'];
    if (locationJson is! Map<String, dynamic>) return;
    final location = BlindLocation.fromJson(locationJson);
    _blindUsers = _blindUsers
        .map((user) {
          if (user.blindUserId != blindUserId) return user;
          return user.copyWith(
            lastLocationAt: location.updatedAt ?? location.capturedAt,
            latestLocation: location,
          );
        })
        .toList(growable: false);
    notifyListeners();
  }

  void _handleSosEvent(dynamic message) {
    if (message is! String) return;
    final decoded = jsonDecode(message);
    if (decoded is! Map<String, dynamic>) return;
    final eventJson = decoded['sos_event'];
    if (eventJson is! Map<String, dynamic>) return;
    final event = FamilySosEvent.fromJson(eventJson);
    final type = decoded['type'];
    if (type == 'sos_acknowledged') {
      _activeSosEvents = _activeSosEvents
          .where((item) => item.sosEventId != event.sosEventId)
          .toList(growable: false);
      notifyListeners();
      return;
    }
    if (event.status != 'active') return;
    final alreadyPresent = _activeSosEvents.any(
      (item) => item.sosEventId == event.sosEventId,
    );
    if (!alreadyPresent) {
      _activeSosEvents = [event, ..._activeSosEvents];
      unawaited(
        _notificationService.showSosAlert(
          blindUserName: event.blindUserName,
          body: '请立即打开领航助手查看并确认。',
        ),
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(disconnectLocationUpdates());
    unawaited(disconnectSosUpdates());
    super.dispose();
  }
}
