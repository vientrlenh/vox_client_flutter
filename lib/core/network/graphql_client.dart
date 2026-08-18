import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

class GraphQLException implements Exception {
  final String message;
  // extensions.code do BE gắn cho một số lỗi (vd PLAN_LIMIT_EXCEEDED) để phân biệt được với các
  // lỗi BAD_REQUEST khác mà không phải so khớp chuỗi message tiếng Việt -- xem GlobalExceptionResolver.
  final String? code;
  GraphQLException(this.message, {this.code});

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
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final SecureStorage _secureStorage;
  final Dio _dio;

  Future<Map<String, dynamic>> query(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    final response = await _dio.post('/graphql', data: {
      'query': query,
      'variables': ?variables,
    });

    final errors = response.data['errors'];
    if (errors != null) {
      final firstError = errors[0] as Map<String, dynamic>;
      final extensions = firstError['extensions'] as Map<String, dynamic>?;
      throw GraphQLException(
        firstError['message'] as String,
        code: extensions?['code'] as String?,
      );
    }

    return response.data['data'] as Map<String, dynamic>;
  }
}
