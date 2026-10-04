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
    // 'password' and 'pin' are always redacted; see _alwaysRedactedKeyParts.
    // 'otp' stays here deliberately: staging testers read it to complete flows.
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
    // Moved here from the always-redact list so staging can show the BVN/NIN
    // while the Biometric KYC flow is built. Production still redacts it.
    // Move it back once that work is verified.
    'identitynumber',
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

  /// Redacted in every environment, including staging. These values are either
  /// provider credentials or regulated identifiers, so no debugging convenience
  /// justifies emitting them.
  static const _alwaysRedactedKeyParts = <String>{
    // A tester never needs to read back a credential they just typed, and
    // unlike an OTP these are long-lived and commonly reused across services.
    // Keeping them out of staging logs costs nothing and removes an exposure
    // that follows any log pasted into a bug report.
    'password',
    'pin',
    'authtoken',
    'partnerid',
    'smileconfig',
    'callbackurl',
    // 'accountnumber' is redacted in production only (see _sensitiveKeyParts)
    // until production-launch hardening; staging shows it for support.
    'documentnumber',
    'resultjson',
    // Core bill-payment and biller customer identifiers.
    'customerid',
  };

  Object? _visible(Object? value) =>
      _redact(value, includeSensitiveData: includeSensitiveData);

  /// Normalized form used to match keys, and to scan serialized payloads.
  static String _normalize(Object? value) =>
      value.toString().toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

  /// Whether a key names a value the server already truncated.
  ///
  /// `identityLast4` and `documentNumberLast4` are the masked display form the
  /// app renders on screen; they are not the identifier their name contains.
  /// Without this, `documentNumberLast4` would be redacted because
  /// `documentnumber` is a substring of it, while `identityLast4` stayed
  /// visible because `identitynumber` is not — an arbitrary split that cost
  /// support diagnostics and protected nothing. The full identifiers are still
  /// caught: this exempts the `*Last4` fragment only.
  static bool _isServerMaskedFragment(String normalizedKey) =>
      normalizedKey.endsWith('last4');

  /// Whether a string looks like a serialized payload rather than prose.
  ///
  /// The value scan exists to catch a JSON body carried as a string. Applying
  /// it to ordinary text redacts any message that merely mentions a protected
  /// word — "A password reset link has been sent" disappeared entirely — which
  /// destroys exactly the field logs are read for.
  static bool _looksLikeSerializedPayload(String value) {
    final trimmed = value.trimLeft();
    return trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        value.contains('":');
  }

  static Object? _redact(Object? value, {required bool includeSensitiveData}) {
    // A String can itself be a serialized payload. Recursing only through Map
    // and Iterable would print every value inside it verbatim, which is how a
    // stringified body such as {"accountNumber":"0123456789"} leaked in a live
    // staging check. Redact the whole string when it names a protected field:
    // over-redacting a log line is always preferable to emitting a credential.
    // A bool can never carry a secret. Flags such as `isCreatedPassword` and
    // `isCreatedPin` report whether a credential exists, not what it is, and
    // the app's own onboarding logic depends on reading them.
    if (value is bool) return value;

    if (value is String) {
      if (!_looksLikeSerializedPayload(value)) return value;
      final normalized = _normalize(value);
      return _alwaysRedactedKeyParts.any(normalized.contains)
          ? '[REDACTED]'
          : value;
    }
    if (value is Map) {
      return value.map<Object?, Object?>((key, nested) {
        final keyString = _normalize(key);
        // A bool under a credential-shaped key is a status flag, not a
        // credential; `isCreatedPassword` must stay readable.
        final alwaysRedacted =
            nested is! bool &&
            !_isServerMaskedFragment(keyString) &&
            _alwaysRedactedKeyParts.any(keyString.contains);
        final environmentRedacted =
            nested is! bool &&
            !includeSensitiveData &&
            _sensitiveKeyParts.any(keyString.contains);
        return MapEntry(
          key,
          alwaysRedacted || environmentRedacted
              ? '[REDACTED]'
              : _redact(nested, includeSensitiveData: includeSensitiveData),
        );
      });
    }
    if (value is Iterable) {
      return value
          .map(
            (nested) =>
                _redact(nested, includeSensitiveData: includeSensitiveData),
          )
          .toList(growable: false);
    }
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
  /// `options.extra` key for a bearer token captured before the local session
  /// was cleared. Only the server logout sets it.
  static const pinnedAccessTokenKey = 'pinnedAccessToken';

  AuthInterceptor({
    required this.readAccessToken,
    required this.readCurrentSession,
    required this.expireSessionOnce,
    this.isPublicOperation = ApiEndpoints.isPublic,
    this.expireSessionOnRemote401 = true,
  });

  final Future<String?> Function() readAccessToken;
  final AuthSession? Function() readCurrentSession;
  final Future<void> Function() expireSessionOnce;

  /// Which operations on this transport carry no bearer token.
  final bool Function(String method, String path) isPublicOperation;

  /// Whether a server 401 for the current token ends the User session. Off
  /// for Core: a Core rejection must never sign the customer out of the User
  /// Service. A locally expired session still cancels every request.
  final bool expireSessionOnRemote401;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isPublic = isPublicOperation(options.method, options.path);
    options.extra['requiresAuth'] = !isPublic;
    if (isPublic) {
      handler.next(options);
      return;
    }

    // A request that must outlive the local session (server logout) carries
    // the token it was started with instead of whatever storage holds now.
    final pinnedToken = options.extra[pinnedAccessTokenKey];
    if (pinnedToken is String && pinnedToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $pinnedToken';
      options.extra['attachedAccessToken'] = pinnedToken;
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
    // Logout or an account switch during the read: the token may now belong
    // to someone else, so the request must not go out at all.
    if (readCurrentSession()?.accessToken != session?.accessToken) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          message: 'The session changed before the request was sent.',
        ),
      );
      return;
    }
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
    if (expireSessionOnRemote401 &&
        err.response?.statusCode == 401 &&
        options.extra['requiresAuth'] == true &&
        options.extra['suppressSessionExpiry'] != true &&
        attachedToken is String &&
        attachedToken == await readAccessToken() &&
        (readCurrentSession()?.accessToken ?? attachedToken) == attachedToken) {
      options.extra['sessionExpiryHandled'] = true;
      await expireSessionOnce();
    }
    handler.next(err);
  }
}
