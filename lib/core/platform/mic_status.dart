import 'dart:io';

import 'package:flutter/services.dart';

/// Hỏi hệ điều hành xem micro của app có đang bị BỊT TIẾNG không.
///
/// Cần cái này vì gói `record` không thể trả lời: từ Android 10, khi một app khác đang giữ micro
/// ở nguồn ưu tiên hơn (Google Meet lúc gọi/chia sẻ màn hình dùng VOICE_COMMUNICATION), hệ thống
/// vẫn cho app thứ hai mở luồng và vẫn đẩy khung dữ liệu về -- chỉ có điều toàn số 0. Không có
/// ngoại lệ nào để bắt, không có mã lỗi nào để đọc: nhìn từ Dart thì mọi thứ y như đang chạy tốt.
///
/// Xem [MainActivity.isMicSilenced] phía Kotlin để biết cờ này lấy từ đâu.
class MicStatus {
  MicStatus._();

  static const MethodChannel _channel = MethodChannel('vox/mic_status');

  /// `true` = đang bị bịt, `false` = đang thu thật, `null` = KHÔNG BIẾT.
  ///
  /// `null` khi nền tảng không có API này (iOS, Android < 10) hoặc app chưa mở micro. Nơi gọi
  /// phải im lặng bỏ qua `null` chứ đừng suy thành "có vấn đề" -- báo động khi không có bằng
  /// chứng còn tệ hơn không báo, vì học sinh sẽ học cách phớt lờ băng cảnh báo.
  /// [sampleRate] là tần số ta đang thu, dùng để nhận ra cấu hình CỦA CHÍNH MÌNH trong danh
  /// sách mà Android trả về -- danh sách đó có cả app khác, xem MainActivity.isMicSilenced.
  static Future<bool?> isSilenced({required int sampleRate}) async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<bool>(
        'isMicSilenced',
        {'sampleRate': sampleRate},
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      // Bản build cũ chưa có phía Kotlin (hot-reload sau khi thêm kênh, hoặc APK cũ) -- không
      // phải lỗi của phiên luyện, đừng làm hỏng nó.
      return null;
    }
  }
}
