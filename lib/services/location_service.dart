import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  Future<Position> getCurrentPosition() async {
    await _checkPermissions();
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 10,
  }) async* {
    await _checkPermissions();
    yield* Geolocator.getPositionStream(
      locationSettings: _streamSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  LocationSettings _streamSettings({
    required LocationAccuracy accuracy,
    required int distanceFilter,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: '领航助手正在守护定位',
          notificationText: '正在为家属持续更新当前位置',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    return LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter);
  }

  Future<void> _checkPermissions() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceException('定位服务未开启，请先打开系统定位服务。');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationServiceException('定位权限被拒绝，无法上传当前位置。');
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException('定位权限已被永久拒绝，请前往系统设置开启。');
    }
  }

  Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }
}
