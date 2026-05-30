import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'device_info.dart';

class DeviceInfoService {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  static const _uuid = Uuid(); 
  static const _androidPlatform = "android";
  static const _iosPlatform = "ios";

  Future<DeviceInfo?> getDeviceInfo() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _getAndroidInfo();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _getIosInfo();
    }
    return null;
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