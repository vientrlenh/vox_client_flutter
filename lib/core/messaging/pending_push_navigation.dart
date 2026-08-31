/// Giữ lại cú bấm vào thông báo đẩy cho tới khi app đủ sẵn sàng để điều hướng.
///
/// Sinh ra vì một thứ tự không thể đảo: `getInitialMessage()` được gọi trong `main()`,
/// TRƯỚC `runApp`, nên lúc đó `AppRouter.navigatorKey.currentState` còn null. Bản cũ điều
/// hướng thẳng tại đó, và vì dùng `?.` nên cú bấm rơi vào hư không mà không báo gì — mở app
/// từ thông báo lúc app đã tắt hẳn thì chỉ về màn hình đăng nhập như bình thường.
///
/// Ngay cả khi có navigator thì vẫn chưa điều hướng được: app khởi động ở màn đăng nhập, mà
/// mọi màn hình đích đều cần phiên đăng nhập. Nơi tiêu thụ vì thế là [MainShell] — chỗ duy
/// nhất chắc chắn đã đăng nhập xong.
class PendingPushNavigation {
  PendingPushNavigation._();

  static Map<String, String>? _pending;

  /// Cất `data` của message đã mở app. Chỉ giữ cái mới nhất: người dùng bấm vào một thông
  /// báo, không phải một hàng đợi.
  static void remember(Map<String, String> data) {
    if (data.isEmpty) return;
    _pending = data;
  }

  /// Lấy ra và xoá. Trả về `null` khi không có gì đang chờ.
  ///
  /// Xoá ngay khi đọc là phần quan trọng: [MainShell] được dựng lại mỗi lần đăng nhập, và
  /// một payload còn sót lại sẽ bật lên một màn hình cũ giữa phiên mới.
  static Map<String, String>? take() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}
