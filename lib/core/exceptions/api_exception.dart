import 'package:dio/dio.dart';

/// A user-presentable error from the backend (or from failing to reach it).
///
/// The backend always replies with `{ success: false, message, details? }` where
/// `details` is a list of `{ field, message }` validation errors.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;

  /// Server-side validation errors keyed by field name (e.g. `email`).
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('The server took too long to respond. Please try again.');
      case DioExceptionType.connectionError:
        return const ApiException('Cannot reach the server. Check your connection and that the API is running.');
      case DioExceptionType.cancel:
        return const ApiException('Request was cancelled.');
      default:
        break;
    }

    final response = e.response;
    final data = response?.data;
    var message = 'Something went wrong. Please try again.';
    final fieldErrors = <String, String>{};

    if (data is Map) {
      if (data['message'] is String) message = data['message'] as String;
      final details = data['details'];
      if (details is List) {
        for (final d in details) {
          if (d is Map && d['field'] is String && d['message'] is String) {
            // Keep the first message per field.
            fieldErrors.putIfAbsent(d['field'] as String, () => d['message'] as String);
          }
        }
      }
    }

    return ApiException(message, statusCode: response?.statusCode, fieldErrors: fieldErrors);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
