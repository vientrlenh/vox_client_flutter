import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../storage/secure_storage.dart';
import 'api_endpoints.dart';
import 'auth_interceptor.dart';
import 'csrf_interceptor.dart';
import 'session_cookies.dart';

class ApiClient {
  ApiClient({
    SecureStorage? secureStorage,
    Dio? dio,
  })  : _secureStorage = secureStorage ?? SecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiEndpoints.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                sendTimeout: const Duration(seconds: 15),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
                headers: const {
                  'Accept': 'application/json',
                },
              ),
            ) {
    _setupInterceptors();
  }

  final SecureStorage _secureStorage;
  final Dio _dio;

  Dio get dio => _dio;

  void _setupInterceptors() {
    // Cookie TRƯỚC xác thực: đăng nhập đi qua chính client này, nên Set-Cookie mang refresh
    // token phải được kho cookie nhận ngay tại đây -- không có nó thì mọi lượt refresh về sau
    // (kể cả từ GraphQLClient) đều thiếu cookie và trượt.
    _dio.interceptors.add(SessionCookies.lazyInterceptor());
    // Ngay sau kho cookie: đăng xuất đi qua client này và /auth/logout đọc cookie refresh_token,
    // nên backend đòi token CSRF -- gửi mỗi cookie là 403. Xem [CsrfInterceptor].
    _dio.interceptors.add(CsrfInterceptor());
    // Bản cũ có onError nhưng chỉ handler.next(error) -- tức thấy 401 rồi thả qua. Nay 401 sẽ
    // làm mới token và chạy lại request.
    _dio.interceptors.add(AuthInterceptor(storage: _secureStorage));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
        ),
      );
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> put(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}