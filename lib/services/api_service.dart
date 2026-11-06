import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/exceptions/api_exception.dart';
import 'storage_service.dart';

/// Thin wrapper around Dio that every feature uses to talk to the backend.
///
/// - Adds `Authorization: Bearer <token>` to every request when logged in.
/// - Converts all failures into [ApiException] so screens deal with one error type.
/// - Calls [onUnauthorized] when an authenticated request gets a 401
///   (token expired or revoked) so the app can return to the login screen.
class ApiService {
  ApiService({required this._storage, Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: ApiConstants.baseUrl,
              connectTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.receiveTimeout,
              headers: {'Accept': 'application/json'},
            )) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await _storage.readToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              handler.next(options);
            },
            onError: (error, handler) {
              final sentToken = error.requestOptions.headers.containsKey('Authorization');
              // A 401 on login (wrong password) is NOT a session expiry, hence the token check.
              if (error.response?.statusCode == 401 && sentToken) {
                onUnauthorized?.call();
              }
              handler.next(error);
            },
          ),
        );
  }

  final StorageService _storage;
  final Dio dio;

  /// Set by the auth layer; invoked when the session is no longer valid.
  void Function()? onUnauthorized;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => dio.get<dynamic>(path, queryParameters: query));

  Future<Map<String, dynamic>> post(String path, {Object? data}) =>
      _send(() => dio.post<dynamic>(path, data: data));

  Future<Map<String, dynamic>> put(String path, {Object? data}) =>
      _send(() => dio.put<dynamic>(path, data: data));

  Future<Map<String, dynamic>> delete(String path) => _send(() => dio.delete<dynamic>(path));

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return <String, dynamic>{};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
