import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../module/onboarding/model/auth_session.dart';
import 'api_endpoints.dart';
import 'api_logger.dart';

class LocalSessionExpired {
  const LocalSessionExpired({required this.suppressed});
  final bool suppressed;
}

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({required this.includeSensitiveData, Logger? logger})
    : _logger = logger ?? apiLogger;

  static const _requestStartedAtKey = 'apiLogger.requestStartedAt';
  static const _sensitiveKeyParts = <String>{
    'authorization',
    'cookie',
    'password',
    'pin',
    'otp',
    'token',
    'secret',
    'identifier',
    'email',
    'phone',
    'firstname',
    'middlename',
    'lastname',
    'bvn',
    'nin',
    'accountnumber',
    'cardnumber',
    'cvv',
  };

  final bool includeSensitiveData;
  final Logger _logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_requestStartedAtKey] = DateTime.now().microsecondsSinceEpoch;
    _logger.i({
      'event': 'REQUEST',
      'method': options.method,
      'url': _urlWithoutQuery(options),
      'query': _visible(options.queryParameters),
      'headers': _visible(options.headers),
      'body': _visible(options.data),
      'extra': _visible(_requestExtra(options)),
    });
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final request = response.requestOptions;
    _logger.i({
      'event': 'RESPONSE',
      'method': request.method,
      'url': _urlWithoutQuery(request),
      'statusCode': response.statusCode,
      'statusMessage': response.statusMessage,
      'durationMs': _durationMilliseconds(request),
      // 'headers': _visible(response.headers.map),
      'body': _visible(response.data),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = err.requestOptions;
    _logger.e(
      {
        'event': 'ERROR',
        'method': request.method,
        'url': _urlWithoutQuery(request),
        'query': _visible(request.queryParameters),
        'statusCode': err.response?.statusCode,
        'durationMs': _durationMilliseconds(request),
        'type': err.type.name,
        'message': includeSensitiveData
            ? err.message
            : 'The API request failed.',
        'requestHeaders': _visible(request.headers),
        'requestBody': _visible(request.data),
        // 'responseHeaders': _visible(err.response?.headers.map),
        'responseBody': _visible(err.response?.data),
      },
      error: includeSensitiveData ? err.error : err.error?.runtimeType,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }

  Object? _visible(Object? value) =>
      includeSensitiveData ? value : _redact(value);

  static Object? _redact(Object? value) {
    if (value is Map) {
      return value.map<Object?, Object?>((key, nested) {
        final keyString = key.toString().toLowerCase().replaceAll(
          RegExp('[^a-z0-9]'),
          '',
        );
        return MapEntry(
          key,
          _sensitiveKeyParts.any(keyString.contains)
              ? '[REDACTED]'
              : _redact(nested),
        );
      });
    }
    if (value is Iterable) return value.map(_redact).toList(growable: false);
    return value;
  }

  static String _urlWithoutQuery(RequestOptions options) {
    final uri = options.uri;
    if (uri.hasScheme && uri.host.isNotEmpty) return '${uri.origin}${uri.path}';
    return options.path.split('?').first;
  }

  static Map<String, Object?> _requestExtra(RequestOptions options) {
    final extra = Map<String, Object?>.from(options.extra);
    extra.remove(_requestStartedAtKey);
    return extra;
  }

  static int? _durationMilliseconds(RequestOptions options) {
    final startedAt = options.extra[_requestStartedAtKey];
    if (startedAt is! int) return null;
    return (DateTime.now().microsecondsSinceEpoch - startedAt) ~/ 1000;
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
    required this.readCurrentSession,
    required this.expireSessionOnce,
  });

  final Future<String?> Function() readAccessToken;
  final AuthSession? Function() readCurrentSession;
  final Future<void> Function() expireSessionOnce;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = ApiEndpoints.isPublic(options.method, options.path);
    options.extra['requiresAuth'] = !isPublic;
    if (isPublic) {
      handler.next(options);
      return;
    }

    final session = readCurrentSession();
    if (session?.isExpired ?? false) {
      final suppressed = options.extra['suppressSessionExpiry'] == true;
      if (!suppressed) {
        options.extra['sessionExpiryHandled'] = true;
        await expireSessionOnce();
      }
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: LocalSessionExpired(suppressed: suppressed),
          message: 'The local session has expired.',
        ),
      );
      return;
    }

    final token = await readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      options.extra['attachedAccessToken'] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attachedToken = options.extra['attachedAccessToken'];
    if (err.response?.statusCode == 401 &&
        options.extra['requiresAuth'] == true &&
        options.extra['suppressSessionExpiry'] != true &&
        attachedToken is String &&
        attachedToken == await readAccessToken()) {
      options.extra['sessionExpiryHandled'] = true;
      await expireSessionOnce();
    }
    handler.next(err);
  }
}
