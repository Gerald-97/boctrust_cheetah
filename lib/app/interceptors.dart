import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import 'response_handler.dart';

class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    developer.log('${options.method} ${options.uri}', name: 'BOCTrust.Api');
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    developer.log(err.message ?? 'Dio error', name: 'BOCTrust.Api', error: err);
    handler.next(err);
  }
}

class ActivityInterceptor extends Interceptor {
  static DateTime lastActivity = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    lastActivity = DateTime.now();
    handler.next(response);
  }
}

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.readAccessToken,
    required this.onExpiredSession,
  });

  final Future<String?> Function() readAccessToken;
  final ExpiredSessionCallback onExpiredSession;

  static const authRouteFragments = <String>[
    '/auth/login',
    '/auth/signup',
    '/auth/forgot-password',
    '/auth/otp',
    '/auth/refresh',
  ];

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!authRouteFragments.any(options.path.contains)) {
      final token = await readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onExpiredSession('Your session has expired. Please sign in again.');
    }
    handler.next(err);
  }
}
