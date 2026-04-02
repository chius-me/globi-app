import 'package:dio/dio.dart';

String resolveApiErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is Map<String, dynamic>) {
        final message = detail['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }

      final message = data['message'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    final message = error.message;
    if (message != null && message.trim().isNotEmpty) {
      return message.trim();
    }
  }

  return fallback;
}

bool isUnauthorizedError(Object error) {
  return error is DioException && error.response?.statusCode == 401;
}
