import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/blind_family_call.dart';
import '../models/blind_identity.dart';
import '../models/blind_link_code.dart';
import '../models/blind_link_result.dart';
import '../models/blind_location.dart';
import '../models/blind_location_upload_result.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_geofence.dart';
import '../models/family_blind_user_map.dart';
import '../models/family_blind_user_location.dart';
import '../models/family_blind_user_route_history.dart';

class BlindLinkApiService {
  final Dio _publicDio;
  final Dio? _protectedDio;

  BlindLinkApiService({Dio? dio, Dio? protectedDio})
    : _publicDio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConstants.backendBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ),
          ),
      _protectedDio = protectedDio;

  Future<BlindLinkCode> createBlindLinkCode({
    required String blindUserName,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.post(
      '/api/family/blind-link-codes',
      data: {'blind_user_name': blindUserName.trim()},
    );

    return BlindLinkCode.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BlindLinkResult> redeemBlindLinkCode({
    required String authorizationCode,
    String? deviceLabel,
  }) async {
    final payload = <String, dynamic>{
      'authorization_code': authorizationCode.trim(),
    };
    final trimmedDeviceLabel = deviceLabel?.trim();
    if (trimmedDeviceLabel != null && trimmedDeviceLabel.isNotEmpty) {
      payload['device_label'] = trimmedDeviceLabel;
    }

    final response = await _publicDio.post('/api/blind/link', data: payload);
    return BlindLinkResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BlindIdentity> getBlindMe({required String blindAccessToken}) async {
    final response = await _publicDio.get(
      '/api/blind/me',
      options: Options(headers: {'Authorization': 'Bearer $blindAccessToken'}),
    );

    return BlindIdentity.fromJson(response.data as Map<String, dynamic>);
  }

  Future<BlindLocationUploadResult> uploadBlindLocation({
    required String blindAccessToken,
    required BlindLocation location,
  }) async {
    final response = await _publicDio.post(
      '/api/blind/location',
      data: location.toUploadJson(),
      options: Options(headers: {'Authorization': 'Bearer $blindAccessToken'}),
    );

    return BlindLocationUploadResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<List<FamilyBlindUser>> listFamilyBlindUsers() async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get('/api/family/blind-users');
    final data = response.data as Map<String, dynamic>;
    final blindUsers = data['blind_users'];
    if (blindUsers is! List) {
      return const [];
    }

    return blindUsers
        .whereType<Map<String, dynamic>>()
        .map(FamilyBlindUser.fromJson)
        .toList(growable: false);
  }

  Future<FamilyBlindUserLocation> getFamilyBlindUserLocation({
    required String blindUserId,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get(
      '/api/family/blind-users/$blindUserId/location',
    );

    return FamilyBlindUserLocation.fromJson(
      response.data as Map<String, dynamic>,
    );
  }

  Future<FamilyBlindUserMap> getFamilyBlindUserMap({
    required String blindUserId,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get('/api/family/blind-users/$blindUserId/map');

    return FamilyBlindUserMap.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FamilyBlindUserRouteHistory> getFamilyBlindUserRouteHistory({
    required String blindUserId,
    int hours = 24,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get(
      '/api/family/blind-users/$blindUserId/route-history',
      queryParameters: {'hours': hours},
    );
    return FamilyBlindUserRouteHistory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FamilyBlindUserGeofence>> listFamilyBlindUserGeofences({
    required String blindUserId,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.get('/api/family/blind-users/$blindUserId/geofences');
    final data = response.data as Map<String, dynamic>;
    final geofences = data['geofences'];
    if (geofences is! List) return const [];
    return geofences
        .whereType<Map<String, dynamic>>()
        .map(FamilyBlindUserGeofence.fromJson)
        .toList(growable: false);
  }

  Future<FamilyBlindUserGeofence> createFamilyBlindUserGeofence({
    required String blindUserId,
    required String label,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.post(
      '/api/family/blind-users/$blindUserId/geofences',
      data: {
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'enabled': true,
      },
    );
    return FamilyBlindUserGeofence.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> deleteFamilyBlindUserGeofence({
    required String blindUserId,
    required String geofenceId,
  }) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.delete(
      '/api/family/blind-users/$blindUserId/geofences/$geofenceId',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) return data['deleted'] as bool? ?? false;
    return false;
  }

  Uri familyLocationWebSocketUri({
    required String blindUserId,
    required String accessToken,
  }) {
    final base = Uri.parse(AppConstants.backendBaseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/ws/family/blind-users/$blindUserId/location',
      queryParameters: {'token': accessToken},
    );
  }

  Future<bool> deleteFamilyBlindUser({required String blindUserId}) async {
    final dio = _protectedDio ?? _publicDio;
    final response = await dio.delete('/api/family/blind-users/$blindUserId');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['deleted'] as bool? ?? false;
    }
    return false;
  }

  Future<BlindFamilyCall> getBlindFamilyCall({
    required String blindAccessToken,
  }) async {
    final response = await _publicDio.get(
      '/api/blind/family-call',
      options: Options(headers: {'Authorization': 'Bearer $blindAccessToken'}),
    );

    return BlindFamilyCall.fromJson(response.data as Map<String, dynamic>);
  }
}
