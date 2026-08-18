import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'token_refresher.dart';

/// Gắn access token vào mỗi request, và khi token hết hạn thì tự làm mới rồi CHẠY LẠI request.
///
/// Dùng chung cho cả [ApiClient] (REST) lẫn [GraphQLClient] -- hai client, một luật.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({SecureStorage? storage, this.onSessionExpired})
      : _storage = storage ?? SecureStorage();

  final SecureStorage _storage;

  /// Gọi khi phiên chết hẳn (refresh cũng hỏng). Nơi gắn interceptor quyết định làm gì --
  /// thường là đưa về màn đăng nhập.
  final Future<void> Function()? onSessionExpired;

  /// Đánh dấu request ĐÃ thử lại một lần. Không có cờ này thì một token vừa làm mới mà vẫn bị
  /// từ chối (tài khoản bị khoá, đổi quyền) sẽ quay vòng refresh - thử lại - 401 vô tận.
  static const _retriedFlag = 'vox_retried_after_refresh';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!_isExpiredAuth(err) || err.requestOptions.extra[_retriedFlag] == true) {
      handler.next(err);
      return;
    }

    final refreshed = await TokenRefresher.refresh();
    if (!refreshed) {
      await TokenRefresher.clearSession();
      await onSessionExpired?.call();
      handler.next(err);
      return;
    }

    try {
      handler.resolve(await _retry(err.requestOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions options) {
    final token = _storage.getAccessToken();
    return token.then((value) {
      final headers = Map<String, dynamic>.from(options.headers);
      if (value != null && value.isNotEmpty) {
        headers['Authorization'] = 'Bearer $value';
      }
      return Dio(BaseOptions(baseUrl: options.baseUrl)).fetch(
        options.copyWith(
          headers: headers,
          extra: {...options.extra, _retriedFlag: true},
        ),
      );
    });
  }

  /// CHỈ 401 mới là "token hết hạn".
  ///
  /// 403 là "đăng nhập rồi nhưng không đủ quyền" -- làm mới token không đổi được điều đó, và
  /// thử lại chỉ tổ giấu mất lỗi phân quyền thật.
  bool _isExpiredAuth(DioException err) => err.response?.statusCode == 401;
}
