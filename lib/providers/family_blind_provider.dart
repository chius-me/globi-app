import 'package:flutter/foundation.dart';

import '../models/blind_link_code.dart';
import '../models/family_blind_user.dart';
import '../models/family_blind_user_map.dart';
import '../models/family_blind_user_location.dart';
import '../services/blind_link_api_service.dart';
import '../utils/api_error.dart';

class FamilyBlindProvider extends ChangeNotifier {
  final BlindLinkApiService _blindApi;

  BlindLinkCode? _latestLinkCode;
  List<FamilyBlindUser> _blindUsers = const [];
  String? _errorMessage;
  bool _isCreatingLinkCode = false;
  bool _isLoadingBlindUsers = false;
  bool _isDeletingBlindUser = false;

  FamilyBlindProvider({required BlindLinkApiService blindApi})
    : _blindApi = blindApi;

  BlindLinkCode? get latestLinkCode => _latestLinkCode;
  List<FamilyBlindUser> get blindUsers => List.unmodifiable(_blindUsers);
  String? get errorMessage => _errorMessage;
  bool get isCreatingLinkCode => _isCreatingLinkCode;
  bool get isLoadingBlindUsers => _isLoadingBlindUsers;
  bool get isDeletingBlindUser => _isDeletingBlindUser;

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
    _latestLinkCode = null;
    _blindUsers = const [];
    _errorMessage = null;
    _isCreatingLinkCode = false;
    _isLoadingBlindUsers = false;
    _isDeletingBlindUser = false;
    notifyListeners();
  }
}
