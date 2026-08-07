class DeviceInfo {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String? pushToken;

  DeviceInfo({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    this.pushToken
  });

  DeviceInfo copyWith({String? pushToken}) {
    return DeviceInfo(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      pushToken: pushToken ?? this.pushToken
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
      if (pushToken != null) 'pushToken': pushToken
    };
  }
}