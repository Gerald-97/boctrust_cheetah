import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../app/api_logger.dart';
import '../app/services.dart';

/// Outcome of a signed binary upload.
///
/// The signed storage endpoint is not the User Service, so its responses never
/// carry the `{ success, message, data, meta }` envelope. Any 2xx is success.
class SignedUploadResult {
  const SignedUploadResult({required this.statusCode});

  final int statusCode;
}

/// Uploads bytes to a short-lived, API-issued signed URL.
///
/// Deliberately separate from [ApiService]: a signed upload must never receive
/// the User Service bearer token, and must never be resolved against the
/// User Service base URL.
abstract interface class SignedUploadClient {
  Future<NotifierState<SignedUploadResult>> putBytes({
    required Uri url,
    required List<int> bytes,
    required Map<String, String> headers,
  });
}

/// Dio instance dedicated to signed uploads.
///
/// No base URL, no default JSON content type, and — critically — no
/// [AuthInterceptor]. Logging is wired separately so uploads stay observable.
final signedUploadDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  ),
);

final signedUploadClientProvider = Provider<SignedUploadClient>(
  (ref) => DioSignedUploadClient(ref.watch(signedUploadDioProvider)),
);

class DioSignedUploadClient implements SignedUploadClient {
  DioSignedUploadClient(this._dio, {Logger? logger})
    : _logger = logger ?? apiLogger;

  final Dio _dio;
  final Logger _logger;

  @override
  Future<NotifierState<SignedUploadResult>> putBytes({
    required Uri url,
    required List<int> bytes,
    required Map<String, String> headers,
  }) async {
    if (url.scheme != 'https') {
      _logger.e({
        'event': 'UPLOAD_REJECTED',
        'reason': 'non-https upload URL',
        'scheme': url.scheme,
      });
      return const NotifierState.error(
        'The upload link was not secure. Request a new link and try again.',
      );
    }

    final startedAt = DateTime.now();
    _logger.i({
      'event': 'UPLOAD_REQUEST',
      'method': 'PUT',
      'url': url.toString(),
      'headers': headers,
      'body': '<binary ${bytes.length} bytes>',
    });

    try {
      final response = await _dio.putUri<Object?>(
        url,
        data: Stream<List<int>>.value(bytes),
        options: Options(
          headers: {...headers, Headers.contentLengthHeader: bytes.length},
          responseType: ResponseType.plain,
          // The storage endpoint owns the status contract; map it ourselves.
          validateStatus: (_) => true,
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final duration = DateTime.now().difference(startedAt);
      final isSuccess = statusCode >= 200 && statusCode < 300;

      _logger.i({
        'event': 'UPLOAD_RESPONSE',
        'url': url.toString(),
        'status': statusCode,
        'durationMs': duration.inMilliseconds,
        if (!isSuccess) 'body': response.data,
      });

      if (isSuccess) {
        return NotifierState.done(SignedUploadResult(statusCode: statusCode));
      }
      return NotifierState.error(
        _failureMessage(statusCode),
        statusCode: statusCode,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      _logger.e({
        'event': 'UPLOAD_ERROR',
        'url': url.toString(),
        'status': statusCode,
        'durationMs': DateTime.now().difference(startedAt).inMilliseconds,
        'type': error.type.name,
        'message': error.message,
        'body': error.response?.data,
      });
      if (statusCode != null) {
        return NotifierState.error(
          _failureMessage(statusCode),
          statusCode: statusCode,
        );
      }
      return NotifierState.error(_transportMessage(error));
    }
  }

  static const _expiredMessage =
      'The upload link expired. Request a new link and try again.';

  static String _failureMessage(int statusCode) => switch (statusCode) {
    400 || 403 => _expiredMessage,
    _ => 'The upload failed. Please try again.',
  };

  static String _transportMessage(DioException error) => switch (error.type) {
    DioExceptionType.connectionError =>
      'No internet connection. Please try again.',
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      'The upload timed out. Please try again.',
    DioExceptionType.cancel => 'The upload was cancelled.',
    _ => error.message ?? 'The upload failed. Please try again.',
  };
}
