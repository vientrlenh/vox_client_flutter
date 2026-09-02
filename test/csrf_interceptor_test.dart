import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vox_client_flutter/core/network/csrf_interceptor.dart';
import 'package:vox_client_flutter/core/network/session_cookies.dart';

const String _baseUrl = 'https://api.voxenta.net/api';
final Uri _refreshUri = Uri.parse('$_baseUrl/v1/auth/refresh');

RequestOptions _refreshRequest({Map<String, dynamic>? headers}) {
  return RequestOptions(
    baseUrl: _baseUrl,
    path: '/v1/auth/refresh',
    method: 'POST',
    headers: headers ?? <String, dynamic>{},
  );
}

Future<void> _giveJarXsrfCookie(String value) async {
  await (await SessionCookies.jar()).saveFromResponse(_refreshUri, [
    Cookie('XSRF-TOKEN', value)..path = '/',
  ]);
}

void main() {
  // Không có plugin path_provider trong test, nên SessionCookies rơi về kho trong RAM -- đúng
  // nhánh dự phòng đã viết sẵn, và vừa đủ cho các test ở đây.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CsrfInterceptor', () {
    setUp(() async {
      await SessionCookies.clear();
    });

    /// Spring không đọc token CSRF từ cookie: cookie chỉ là bản "mong đợi", bản "thật" phải nằm
    /// trong header. Thiếu bước chép này thì /auth/refresh trả 403 và người dùng bị đá về màn
    /// đăng nhập sau đúng 15 phút.
    test('copies the XSRF-TOKEN cookie into the X-XSRF-TOKEN header', () async {
      await _giveJarXsrfCookie('token-abc');
      final options = _refreshRequest();

      await CsrfInterceptor().onRequest(options, RequestInterceptorHandler());

      expect(options.headers['X-XSRF-TOKEN'], 'token-abc');
    });

    test('leaves an explicitly set header alone', () async {
      await _giveJarXsrfCookie('token-from-jar');
      final options = _refreshRequest(
        headers: <String, dynamic>{'X-XSRF-TOKEN': 'token-set-by-caller'},
      );

      await CsrfInterceptor().onRequest(options, RequestInterceptorHandler());

      expect(options.headers['X-XSRF-TOKEN'], 'token-set-by-caller');
    });

    /// Máy chưa từng gọi API nào thì chưa có cookie. Request vẫn phải đi ra -- cùng lắm là 403
    /// ở đúng endpoint cần token, chứ không phải chặn ngay từ client.
    test('sends the request unchanged when there is no cookie yet', () async {
      final options = _refreshRequest();

      await CsrfInterceptor().onRequest(options, RequestInterceptorHandler());

      expect(options.headers.containsKey('X-XSRF-TOKEN'), isFalse);
    });
  });
}
