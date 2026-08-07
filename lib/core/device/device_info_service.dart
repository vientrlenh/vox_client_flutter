import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'device_info.dart';

class DeviceInfoService {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  static const _uuid = Uuid(); 
  static const _androidPlatform = "android";
  static const _iosPlatform = "ios";
  static const _webPlatform = "web";
  static const _desktopPlatform = "desktop";

  Future<DeviceInfo?> getDeviceInfo() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _getAndroidInfo();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _getIosInfo();
    }
    if (kIsWeb) {
      return DeviceInfo(deviceId: _uuid.v7(), deviceName: 'Web browser', platform: _webPlatform);
    }
    // desktop platforms (linux/macos/windows) share one device_info_plus
    // call and one SessionPlatform value; split per-OS if device_info_plus fields
    // ever need to differ (e.g. showing the real hostname to the user).
    return DeviceInfo(deviceId: _uuid.v7(), deviceName: 'Desktop', platform: _desktopPlatform);
  }

  Future<DeviceInfo> _getAndroidInfo() async {
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    return DeviceInfo(
      deviceId: _uuid.v7(), 
      deviceName: androidInfo.model, 
      platform: _androidPlatform
    );
  }

  Future<DeviceInfo> _getIosInfo() async {
    IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
    return DeviceInfo(
      deviceId: _uuid.v7(), 
      deviceName: iosInfo.model, 
      platform: _iosPlatform
    );
  }
}