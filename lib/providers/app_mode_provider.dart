import 'package:flutter/foundation.dart';

import '../services/secure_storage_service.dart';

enum AppMode { unknown, unselected, blind, family }

class AppModeProvider extends ChangeNotifier {
  final SecureStorageService _storage;

  AppMode _mode = AppMode.unknown;

  AppModeProvider({required SecureStorageService storage}) : _storage = storage;

  AppMode get mode => _mode;
  bool get requiresAuth => _mode == AppMode.family;
  bool get isBlindMode => _mode == AppMode.blind;

  Future<void> initialize() async {
    final storedMode = await _storage.getAppMode();
    _mode = switch (storedMode) {
      'blind' => AppMode.blind,
      'family' => AppMode.family,
      _ => AppMode.unselected,
    };
    notifyListeners();
  }

  Future<void> selectBlindMode() async {
    _mode = AppMode.blind;
    await _storage.saveAppMode('blind');
    notifyListeners();
  }

  Future<void> selectFamilyMode() async {
    _mode = AppMode.family;
    await _storage.saveAppMode('family');
    notifyListeners();
  }

  Future<void> resetMode() async {
    _mode = AppMode.unselected;
    await _storage.clearAppMode();
    notifyListeners();
  }
}
