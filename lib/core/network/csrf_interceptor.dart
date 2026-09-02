import 'package:dio/dio.dart';

import 'session_cookies.dart';

/// Chép token CSRF từ cookie `XSRF-TOKEN` sang header `X-XSRF-TOKEN`.
///
/// Vì sao cần dù đã có kho cookie: Spring KHÔNG đọc token CSRF từ cookie. Cookie chỉ là bản
/// "token mong đợi" (`CookieCsrfTokenRepository`); bản "token thật" phải nằm trong header
/// `X-XSRF-TOKEN` hoặc tham số `_csrf`, và `CsrfFilter` so hai bản đó với nhau. Gửi mỗi cookie
/// thì bản thật là null -> 403. Đây chính là lý do gửi cookie thôi là chưa đủ.
///
/// Hỏng ra sao nếu thiếu: `TokenRefresher._run()` nuốt mọi lỗi và trả `false`, mà `false` được
/// [AuthInterceptor] hiểu là "phiên chết hẳn" -> `clearSession()`. Người dùng bị đá về màn đăng
/// nhập sau đúng 15 phút mỗi lần dùng app, đúng triệu chứng mà kho cookie sinh ra để chữa.
///
/// Chỉ hai endpoint trên chain API cần: `POST /v1/auth/refresh` và `POST /v1/auth/logout` -- đó
/// là hai chỗ duy nhất backend đọc cookie (xem `SecurityConfig.CSRF_PROTECTED_API_PATHS`). Vẫn
/// gắn cho cả client thay vì lọc theo path: gắn thừa một header vào request không cần nó thì
/// backend bỏ qua, còn quên gắn ở chỗ cần thì hỏng theo kiểu chỉ lộ ra sau 15 phút. Backend có
/// thêm endpoint đọc cookie nữa thì ở đây không phải sửa gì.
class CsrfInterceptor extends Interceptor {
  static const String _cookieName = 'XSRF-TOKEN';
  static const String _headerName = 'X-XSRF-TOKEN';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.headers.containsKey(_headerName)) {
      handler.next(options);
      return;
    }

    try {
      final cookies = await (await SessionCookies.jar()).loadForRequest(
        options.uri,
      );
      for (final cookie in cookies) {
        if (cookie.name == _cookieName) {
          // KHÔNG giải mã URL: token mặc định của Spring là một UUID, không có ký tự cần
          // encode, nên giải mã chỉ tạo cơ hội làm hỏng giá trị chứ không sửa được gì.
          options.headers[_headerName] = cookie.value;
          break;
        }
      }
    } catch (_) {
      // Đọc kho cookie hỏng thì cứ gửi request đi: cùng lắm là 403 ở đúng hai endpoint cần
      // token, còn chặn ở đây là chặn nhầm cả những request vốn không liên quan gì tới CSRF.
    }

    handler.next(options);
  }
}
