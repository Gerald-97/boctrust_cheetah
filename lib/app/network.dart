import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/secure_storage.dart';
import '../module/onboarding/provider/auth_session_provider.dart';
import 'interceptors.dart';
import 'services.dart';
import 'session_expiry_coordinator.dart';

typedef ApiDataParser<T> = T Function(Object? data);

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl(),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.interceptors.addAll([
    AuthInterceptor(
      readAccessToken: storage.readAccessToken,
      readCurrentSession: () => ref.read(authSessionProvider),
      expireSessionOnce: () =>
          ref.read(sessionExpiryCoordinatorProvider).expireOnce(),
    ),
    LoggingInterceptor(includeSensitiveData: Env.isStaging),
    ActivityInterceptor(),
  ]);
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
    required ApiDataParser<T> parser,
    Map<String, dynamic>? queryParameters,
    Map<String, Object?>? requestExtra,
  }) => _request(
    () => _dio.get<Object?>(
      path,
      queryParameters: queryParameters,
      options: Options(extra: requestExtra),
    ),
    parser,
  );

  Future<ServiceResponse<T>> postData<T>(
    String path, {
    Object? data,
    required ApiDataParser<T> parser,
    Map<String, Object?>? requestExtra,
  }) => _request(
    () => _dio.post<Object?>(
      path,
      data: data,
      options: Options(extra: requestExtra),
    ),
    parser,
  );

  Future<ServiceResponse<T>> patchData<T>(
    String path, {
    Object? data,
    required ApiDataParser<T> parser,
    Map<String, Object?>? requestExtra,
  }) => _request(
    () => _dio.patch<Object?>(
      path,
      data: data,
      options: Options(extra: requestExtra),
    ),
    parser,
  );

  Future<ServiceResponse<T>> deleteData<T>(
    String path, {
    Object? data,
    required ApiDataParser<T> parser,
    Map<String, Object?>? requestExtra,
  }) => _request(
    () => _dio.delete<Object?>(
      path,
      data: data,
      options: Options(extra: requestExtra),
    ),
    parser,
  );

  Future<ServiceResponse<T>> _request<T>(
    Future<Response<Object?>> Function() call,
    ApiDataParser<T> parser,
  ) async {
    try {
      return _mapResponse(await call(), parser);
    } on DioException catch (error) {
      return _mapDioException(error, parser);
    } catch (_) {
      return const ServiceResponse.error('The server response was invalid.');
    }
  }

  ServiceResponse<T> _mapResponse<T>(
    Response<Object?> response,
    ApiDataParser<T> parser,
  ) {
    final statusCode = response.statusCode;
    final body = response.data;
    if (body is! Map) {
      return ServiceResponse<T>.error(
        'The server response was invalid.',
        statusCode: statusCode,
      );
    }
    final json = Map<String, Object?>.from(body);
    final message = json['message'] as String?;
    final meta = ApiMeta.fromJson(json['meta']);
    if (json['success'] != true) {
      return ServiceResponse<T>(
        status: ServiceStatus.error,
        data: _conflictData(statusCode, json, parser),
        message: message ?? 'Request failed.',
        statusCode: statusCode,
        errorCode: json['code'] as String?,
        errors: _errors(json['errors']),
        meta: meta,
      );
    }

    try {
      return ServiceResponse<T>.success(
        parser(json['data']),
        message: message,
        statusCode: statusCode,
        meta: meta,
      );
    } catch (_) {
      return ServiceResponse<T>.error(
        'The server response was invalid.',
        statusCode: statusCode,
        meta: meta,
      );
    }
  }

  ServiceResponse<T> _mapDioException<T>(
    DioException error,
    ApiDataParser<T> parser,
  ) {
    final statusCode = error.response?.statusCode;
    final noAuth = error.requestOptions.extra['sessionExpiryHandled'] == true;
    if (error.error is LocalSessionExpired) {
      return ServiceResponse<T>.error(
        'Your session has expired. Please sign in again.',
        statusCode: 401,
        noAuth: noAuth,
      );
    }

    final body = error.response?.data;
    if (body is Map) {
      final json = Map<String, Object?>.from(body);
      return ServiceResponse<T>(
        status: ServiceStatus.error,
        data: _conflictData(statusCode, json, parser),
        message: json['message'] as String? ?? 'Request failed.',
        statusCode: statusCode,
        errorCode: json['code'] as String?,
        errors: _errors(json['errors']),
        meta: ApiMeta.fromJson(json['meta']),
        noAuth: noAuth,
      );
    }

    return ServiceResponse<T>.error(
      _transportMessage(error),
      statusCode: statusCode,
      noAuth: noAuth,
    );
  }

  /// A 409 may return the resource already in the way (for KYC, the
  /// verification in progress) so the caller can reopen it. Any other error's
  /// data, or conflict data that does not parse, is dropped.
  static T? _conflictData<T>(
    int? statusCode,
    Map<String, Object?> json,
    ApiDataParser<T> parser,
  ) {
    if (statusCode != 409 || json['data'] == null) return null;
    try {
      return parser(json['data']);
    } catch (_) {
      return null;
    }
  }

  static List<Object?> _errors(Object? value) {
    if (value == null) return const [];
    if (value is List) return List<Object?>.unmodifiable(value);
    if (value is Map) {
      return [Map<String, Object?>.unmodifiable(Map.from(value))];
    }
    return [value];
  }

  static String _transportMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionError =>
      'No internet connection. Please try again.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'Request timed out. Please try again.',
    DioExceptionType.cancel => 'Request was cancelled.',
    _ => error.message ?? 'Network request failed.',
  };
}
