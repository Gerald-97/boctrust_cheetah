import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'interceptors.dart';
import 'services.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.interceptors.addAll([LoggingInterceptor(), ActivityInterceptor()]);
  return dio;
});

final apiServiceProvider = Provider<ApiService>(
  (ref) => ApiService(ref.watch(dioProvider)),
);

class ApiService {
  const ApiService(this._dio);

  final Dio _dio;

  Future<ServiceResponse<T>> getData<T>(
    String path, {
    T Function(Object? json)? parser,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );
      return _mapResponse(response, parser);
    } on DioException catch (error) {
      return ServiceResponse<T>.error(
        error.message ?? 'Network request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Future<ServiceResponse<T>> postData<T>(
    String path, {
    Object? data,
    T Function(Object? json)? parser,
  }) async {
    try {
      final response = await _dio.post<Object?>(path, data: data);
      return _mapResponse(response, parser);
    } on DioException catch (error) {
      return ServiceResponse<T>.error(
        error.message ?? 'Network request failed',
        statusCode: error.response?.statusCode,
      );
    }
  }

  ServiceResponse<T> _mapResponse<T>(
    Response<Object?> response,
    T Function(Object? json)? parser,
  ) {
    final statusCode = response.statusCode;
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      final body = response.data;
      if (body == null || body == '') {
        return ServiceResponse<T>.empty(statusCode: statusCode);
      }
      return ServiceResponse<T>.success(
        parser == null ? body as T : parser(body),
        statusCode: statusCode,
      );
    }
    return ServiceResponse<T>.error('Request failed', statusCode: statusCode);
  }
}
