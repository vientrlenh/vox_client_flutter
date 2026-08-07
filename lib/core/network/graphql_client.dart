import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

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
      if (variables != null) 'variables': variables,
    });

    final errors = response.data['errors'];
    if (errors != null) {
      throw GraphQLException(errors[0]['message'] as String);
    }

    return response.data['data'] as Map<String, dynamic>;
  }
}
