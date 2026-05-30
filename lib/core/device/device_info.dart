class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform
    };
  }
}