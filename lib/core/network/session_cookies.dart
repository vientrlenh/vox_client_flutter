import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Kho cookie DÙNG CHUNG cho mọi Dio trong app.
///
/// Vì sao cần: refresh token của backend không nằm trong body đăng nhập -- `LoginResponse` trả
/// `refreshToken = null` và token thật chỉ đi ra bằng `Set-Cookie` (httpOnly). Endpoint
/// `/api/v1/auth/refresh` lại đòi đúng cookie đó (`@CookieValue(required = true)`). Dio không tự
/// giữ cookie, nên trước đây mobile lưu `null` vào secure storage và **không bao giờ** làm mới
/// được phiên: access token hết hạn sau 15 phút là mọi lời gọi hỏng cho tới khi đăng nhập lại.
///
/// Phải DÙNG CHUNG một kho: đăng nhập đi qua [ApiClient] (REST) còn phần lớn màn hình đi qua
/// [GraphQLClient]. Hai kho riêng thì cookie nhận lúc đăng nhập không có mặt lúc cần refresh.
///
/// Lưu xuống đĩa chứ không giữ trong RAM: đóng app mở lại vẫn còn phiên, đúng như người dùng
/// mong đợi -- và đó cũng là điều kiện để refresh token 3 ngày có ý nghĩa.
class SessionCookies {
  SessionCookies._();

  static CookieJar? _jar;
  static Future<CookieJar>? _pending;

  /// Khởi tạo một lần rồi dùng lại. Gọi song song cũng chỉ tạo một kho: lần gọi đầu giữ
  /// [_pending], các lần sau chờ chính future đó thay vì dựng kho thứ hai đè lên.
  static Future<CookieJar> jar() {
    final ready = _jar;
    if (ready != null) return Future.value(ready);
    return _pending ??= _create();
  }

  static Future<CookieJar> _create() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final jar = PersistCookieJar(storage: FileStorage('${directory.path}/.cookies/'));
      _jar = jar;
      return jar;
    } catch (_) {
      // Không ghi được xuống đĩa (quyền, hệ máy lạ) thì vẫn phải chạy: kho trong RAM giữ được
      // phiên tới khi đóng app. Mất phiên lúc khởi động lại còn hơn hỏng hẳn việc đăng nhập.
      final jar = CookieJar();
      _jar = jar;
      return jar;
    }
  }

  /// Gắn kho cookie vào một Dio. Đặt TRƯỚC interceptor làm mới token để cookie đã sẵn sàng
  /// trước khi lời gọi refresh đi ra.
  static Future<void> attach(Dio dio) async {
    dio.interceptors.add(CookieManager(await jar()));
  }

  /// Xoá sạch cookie -- gọi lúc đăng xuất, cùng lúc với xoá access/refresh token.
  ///
  /// Bỏ bước này thì cookie phiên cũ còn nằm đó, và lần đăng nhập sau của người khác trên cùng
  /// máy có thể refresh nhầm sang phiên của người trước.
  static Future<void> clear() async {
    try {
      await (await jar()).deleteAll();
    } on FileSystemException {
      // Kho trên đĩa đã bị xoá sẵn -- không có gì để dọn.
    }
  }

  /// Bản ĐỒNG BỘ cho các client dựng trong constructor.
  ///
  /// Mở kho là việc bất đồng bộ (phải hỏi đường dẫn thư mục), nhưng `GraphQLClient()` và
  /// `ApiClient()` được `new` rải rác khắp app nên không có chỗ nào `await` được. Interceptor
  /// này tự chờ kho ở từng request thay vì bắt nơi gọi phải chờ -- nhờ vậy không cần nhớ khởi
  /// tạo trước ở `main()`, và quên cũng không âm thầm mất cookie.
  static Interceptor lazyInterceptor() => _LazyCookieInterceptor();
}

class _LazyCookieInterceptor extends Interceptor {
  CookieManager? _delegate;

  Future<CookieManager> _resolve() async =>
      _delegate ??= CookieManager(await SessionCookies.jar());

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    (await _resolve()).onRequest(options, handler);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    (await _resolve()).onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    (await _resolve()).onError(err, handler);
  }
}
