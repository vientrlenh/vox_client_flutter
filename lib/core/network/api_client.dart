import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../app/router.dart';
import '../storage/secure_storage.dart';
import 'api_endpoints.dart';

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

  /// Khoá refresh dùng chung cho MỌI instance của [ApiClient] (không có DI
  /// singleton trong app, mỗi màn hình tự `ApiClient()` riêng) -- nếu để là field
  /// thường thì hai request 401 cùng lúc từ hai instance khác nhau sẽ gọi
  /// `/v1/auth/refresh` hai lần, và lần thứ hai sẽ nuốt luôn access token mới
  /// vừa được lần đầu tạo ra (refresh token cũ đã bị đánh dấu used).
  static Completer<bool>? _refreshCompleter;

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.getAccessToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (error, handler) async {
          final statusCode = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthEndpoint =
              path == ApiEndpoints.login || path == ApiEndpoints.googleLogin || path == ApiEndpoints.refresh;

          if (statusCode != 401 || isAuthEndpoint) {
            handler.next(error);
            return;
          }

          if (!await _refreshAccessToken()) {
            handler.next(error);
            return;
          }

          try {
            final newToken = await _secureStorage.getAccessToken();
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newToken';
            handler.resolve(await _dio.fetch(retryOptions));
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );

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

  /// Refresh access token khi request ăn 401. Nhiều request cùng lúc chỉ kích
  /// một lần gọi `/v1/auth/refresh` thật sự -- các request khác đợi chung kết quả
  /// qua [_refreshCompleter] (refresh token bị đánh dấu "used" ngay sau lần đầu
  /// dùng, gọi trùng sẽ làm request thứ hai bị backend từ chối).
  ///
  /// Trả `false` và đăng xuất cưỡng bức khi không refresh được -- phiên đã hết
  /// hạn thật sự (refresh token cũng hết hạn/bị thu hồi), không có gì để thử lại.
  Future<bool> _refreshAccessToken() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    Future(() async {
      try {
        final deviceId = await _secureStorage.getDeviceId();
        final refreshToken = await _secureStorage.getRefreshToken();
        if (deviceId == null || refreshToken == null) {
          await _forceLogout();
          completer.complete(false);
          return;
        }

        final response = await Dio(_dio.options).post(ApiEndpoints.refresh, data: {
          'deviceId': deviceId,
          'refreshToken': refreshToken,
        });
        final data = response.data['data'] as Map<String, dynamic>;

        await _secureStorage.saveAccessToken(data['accessToken'] as String);
        final newRefreshToken = data['refreshToken'] as String?;
        if (newRefreshToken != null) {
          await _secureStorage.saveRefreshToken(newRefreshToken);
        }

        completer.complete(true);
      } catch (_) {
        await _forceLogout();
        completer.complete(false);
      } finally {
        _refreshCompleter = null;
      }
    });

    return completer.future;
  }

  Future<void> _forceLogout() async {
    await _secureStorage.clearAccessToken();
    await _secureStorage.clearRefreshToken();
    AppRouter.navigatorKey.currentState
        ?.pushNamedAndRemoveUntil(AppRouter.login, (route) => false);
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