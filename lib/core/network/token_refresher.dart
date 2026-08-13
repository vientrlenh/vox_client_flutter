import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'session_cookies.dart';

/// Làm mới access token khi nó hết hạn, dùng chung cho MỌI Dio trong app.
///
/// Vì sao cần: access token sống 15 phút (`JWT_EXPIRATION_MS = 900000`). Trước đây app lưu
/// refresh token nhưng không chỗ nào gọi `/auth/refresh`, nên hết 15 phút là mọi lời gọi hỏng
/// tới khi người dùng tự đăng xuất rồi đăng nhập lại. Triệu chứng lộ ra rất khác nhau tuỳ màn:
/// màn luyện nói bắt làm lại quiz sở thích (vì nó nuốt lỗi rồi giữ cờ cũ), màn kết quả thì kẹt
/// ở "đang chờ kết quả" -- cùng một nguyên nhân, hai bộ mặt.
///
/// Refresh token đi bằng COOKIE, không nằm trong body -- xem [SessionCookies].
class TokenRefresher {
  TokenRefresher._();

  static final SecureStorage _storage = SecureStorage();

  /// Lượt refresh đang chạy. Nhiều request cùng hỏng một lúc thì CHỈ một lượt refresh được
  /// gọi, các request kia chờ chính future này.
  ///
  /// Thiếu chốt này là hỏng thật chứ không chỉ phí: mở app ra là 4-5 màn bắn query cùng lúc,
  /// tất cả cùng 401, thành 5 lời gọi refresh song song. Backend xoay vòng refresh token mỗi
  /// lần dùng, nên lượt đầu thành công còn 4 lượt sau cầm token đã bị vô hiệu -> đăng xuất
  /// người dùng ngay giữa lúc mọi thứ đang bình thường.
  static Future<bool>? _inFlight;

  /// Dio RIÊNG, không gắn interceptor xác thực nào -- nếu dùng chung client thường thì lời gọi
  /// refresh mà lỗi sẽ lại kích hoạt refresh, đệ quy vô tận.
  static Dio? _client;

  static Future<Dio> _refreshClient() async {
    final existing = _client;
    if (existing != null) return existing;
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    await SessionCookies.attach(dio);
    _client = dio;
    return dio;
  }

  /// Trả `true` nếu đã có access token mới. `false` nghĩa là phiên chết hẳn -- nơi gọi nên
  /// đưa người dùng về màn đăng nhập.
  static Future<bool> refresh() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<bool> _run() async {
    try {
      // deviceId phải ĐÚNG cái đã dùng lúc đăng nhập: backend đối chiếu nó
      // (RefreshUseCase -> deviceSession.isDeviceIdMismatches). AuthRepository đã lưu lại ngay
      // sau khi đăng nhập thành công, nên đọc ra dùng chứ TUYỆT ĐỐI không sinh mới -- mỗi lần
      // DeviceInfoService.getDeviceInfo() gọi là một UUID khác, refresh sẽ trượt vì lệch thiết bị.
      final deviceId = await _storage.getDeviceId();
      if (deviceId == null || deviceId.isEmpty) {
        return false;
      }

      final dio = await _refreshClient();
      final response = await dio.post(
        '/v1/auth/refresh',
        data: {'deviceId': deviceId},
      );

      final token = (response.data['data'] as Map<String, dynamic>?)?['accessToken'] as String?;
      if (token == null || token.isEmpty) {
        return false;
      }
      await _storage.saveAccessToken(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Dọn sạch phiên. Gọi khi refresh thất bại, và khi người dùng chủ động đăng xuất.
  static Future<void> clearSession() async {
    await _storage.clearAccessToken();
    await _storage.clearRefreshToken();
    await SessionCookies.clear();
  }
}
