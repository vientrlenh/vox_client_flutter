import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'auth_interceptor.dart';
import 'session_cookies.dart';
import 'token_refresher.dart';

class GraphQLException implements Exception {
  final String message;
  GraphQLException(this.message);

  @override
  String toString() => message;
}

class GraphQLClient {
  GraphQLClient({SecureStorage? secureStorage, Dio? dio})
      : _secureStorage = secureStorage ?? SecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiEndpoints.graphqlBaseUrl,
                // 30s chứ không 15s: vài mutation phải chờ backend nhờ AI làm việc thật --
                // dựng đề luyện có thể phải sinh câu mới (10-40s ở đường chậm), quiz sở thích
                // sinh riêng cho học sinh mất 12-22s. 15s cắt ngang giữa chừng thì client báo
                // lỗi trong khi backend vẫn đang làm và vẫn ghi kết quả xuống DB -- người dùng
                // thấy hỏng còn dữ liệu thì có, kiểu sai lệch khó lần nhất.
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                sendTimeout: const Duration(seconds: 30),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            ) {
    // Thứ tự QUAN TRỌNG: cookie trước, xác thực sau. Interceptor xác thực có thể gọi
    // /auth/refresh, mà lời gọi đó cần cookie refresh token đã được nạp sẵn.
    _dio.interceptors.add(SessionCookies.lazyInterceptor());
    // Trước 2026-08-11 chỗ này chỉ gắn Bearer token, không có nhánh lỗi nào. Access token sống
    // 15 phút nên hết hạn là mọi query hỏng cho tới khi người dùng tự đăng xuất/đăng nhập lại.
    _dio.interceptors.add(AuthInterceptor(storage: _secureStorage));
  }

  final SecureStorage _secureStorage;
  final Dio _dio;

  /// [retried] chỉ dùng nội bộ cho lần gọi lại sau khi làm mới token -- nơi khác đừng truyền.
  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic>? variables,
    bool retried = false,
  }) async {
    final response = await _dio.post('/graphql', data: {
      'query': query,
      'variables': ?variables,
    });

    final errors = response.data['errors'];
    if (errors != null) {
      // Token hết hạn -> làm mới rồi gửi lại ĐÚNG query này.
      //
      // Phải xử lý ở ĐÂY chứ không phải trong AuthInterceptor: GraphQL trả lỗi trong BODY với
      // HTTP 200 (đúng chuẩn của nó), nên `onError` của Dio không bao giờ chạy. Đo trên chính
      // backend này: `/api/**` với token hỏng trả 401, còn `/graphql` trả 200 kèm
      // `extensions.classification = "UNAUTHORIZED"`. Mà gần như toàn bộ app đi qua GraphQL --
      // chỉ đăng nhập/đăng xuất dùng REST -- nên interceptor một mình là vô tác dụng.
      if (!retried && _isUnauthorized(errors)) {
        if (await TokenRefresher.refresh()) {
          return this.query(query, variables: variables, retried: true);
        }
        // Refresh cũng hỏng nghĩa là phiên chết hẳn: dọn sạch để lần sau không thử lại bằng
        // một token đã vô hiệu.
        await TokenRefresher.clearSession();
      }
      throw GraphQLException(errors[0]['message'] as String);
    }

    return response.data['data'] as Map<String, dynamic>;
  }

  /// Dựa vào `extensions.classification`, KHÔNG so chuỗi `message`.
  ///
  /// `message` là câu chữ cho người đọc ("Access Denied") -- đổi lúc nào cũng được và không có
  /// gì đảm bảo. `classification` mới là phần hợp đồng dành cho máy.
  bool _isUnauthorized(dynamic errors) {
    if (errors is! List) return false;
    return errors.any((error) {
      final extensions = (error is Map) ? error['extensions'] : null;
      final classification =
          (extensions is Map) ? extensions['classification'] : null;
      return classification == 'UNAUTHORIZED';
    });
  }
}
