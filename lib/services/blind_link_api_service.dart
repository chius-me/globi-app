import 'package:dio/dio.dart';

import '../config/constants.dart';
import '../models/blind_identity.dart';
import '../models/blind_link_code.dart';
import '../models/blind_link_result.dart';
import '../models/blind_location.dart';
import '../models/blind_location_upload_result.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_location.dart';

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
}
