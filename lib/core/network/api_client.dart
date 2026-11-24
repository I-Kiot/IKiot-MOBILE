import 'dart:async';

import 'package:dio/dio.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Một client duy nhất tới IKiot-BE.
///
/// - Gắn `Authorization: Bearer` vào mọi request.
/// - Gặp 401 thì gọi `/auth/refresh` **một lần** cho mọi request đang chờ, rồi gửi lại.
///   BE xoay refresh token mỗi lần (token cũ bị xoá), nên hai lần refresh song song sẽ có một
///   lần thất bại và đăng xuất người dùng oan.
/// - Bóc envelope `{ success, data }`: hàm gọi nhận thẳng `data`.
class ApiClient {
  ApiClient({required this._tokens, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Env.apiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: _attachToken,
        onError: _refreshOn401,
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokens;
  Future<_RefreshResult>? _refreshing;

  /// Gọi khi refresh thất bại: phiên đã chết, app phải về màn đăng nhập.
  void Function()? onSessionExpired;

  /// Id socket realtime đang nối. Gửi kèm (`X-Socket-Id`) để BE không phát `entity:changed` ngược lại cho
  /// chính máy vừa ghi: màn của máy này đã tự cập nhật từ response rồi.
  String? Function()? socketIdProvider;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post<dynamic>(path, data: body));

  /// Gửi một tệp dạng multipart (trường `file`), như `POST /uploads`.
  Future<dynamic> upload(String path, String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return _send(() => _dio.post<dynamic>(path, data: form));
  }

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      // Danh sách phân trang trả `{ success, data, pagination }`: giữ nguyên để màn đọc được pagination.
      if (body is Map<String, dynamic> && body.containsKey('pagination')) {
        return body;
      }
      if (body is Map<String, dynamic> && body.containsKey('data')) {
        return body['data'];
      }
      return body;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.readAccess();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    final socketId = socketIdProvider?.call();
    if (socketId != null) options.headers['X-Socket-Id'] = socketId;
    handler.next(options);
  }

  Future<void> _refreshOn401(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final options = error.requestOptions;
    final isAuthCall =
        options.path.startsWith('/auth/login') ||
        options.path.startsWith('/auth/refresh');
    if (error.response?.statusCode != 401 ||
        isAuthCall ||
        options.extra['retried'] == true) {
      return handler.next(error);
    }

    final result = await (_refreshing ??= _refresh().whenComplete(
      () => _refreshing = null,
    ));
    if (result == _RefreshResult.rejected) onSessionExpired?.call();
    if (result != _RefreshResult.refreshed) return handler.next(error);

    try {
      final token = await _tokens.readAccess();
      options.headers['Authorization'] = 'Bearer $token';
      options.extra['retried'] = true;
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<_RefreshResult> _refresh() async {
    final refreshToken = await _tokens.readRefresh();
    if (refreshToken == null) return _RefreshResult.rejected;
    try {
      // Dio riêng, không qua interceptor: refresh lỗi 401 không được tự gọi refresh lần nữa.
      final response = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post<Map<String, dynamic>>(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
      final data = response.data?['data'] as Map<String, dynamic>?;
      if (data == null) return _RefreshResult.rejected;
      await _tokens.save(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return _RefreshResult.refreshed;
    } on DioException catch (error) {
      // Mất mạng giữa chừng không phải phiên hết hạn: giữ token, để lần sau thử lại.
      // Shipper hay đi qua vùng sóng yếu, đăng xuất họ vì thế là bắt đăng nhập lại giữa đường.
      if (error.response == null) return _RefreshResult.offline;
      await _tokens.clear();
      return _RefreshResult.rejected;
    }
  }
}

enum _RefreshResult { refreshed, rejected, offline }
