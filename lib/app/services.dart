import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'response_handler.dart';

abstract final class Env {
  static const environment = String.fromEnvironment('ENV');
  static const baseUrl = String.fromEnvironment('BASE_URL');

  /// Core Service root using the same `/api` convention as [baseUrl]. Blank
  /// means Core is not configured: the app boots and every Core capability
  /// stays unavailable.
  static const coreBaseUrl = String.fromEnvironment('CORE_BASE_URL');
  static bool get hasCoreBaseUrl => coreBaseUrl.trim().isNotEmpty;
  static const secureStorageNamespace = String.fromEnvironment(
    'SECURE_STORAGE_NAMESPACE',
  );
  static const paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
  );
  static const dojahSelfieWidgetId = String.fromEnvironment(
    'DOJAH_SELFIE_WIDGET_ID',
  );
  static const dojahGovernmentWidgetId = String.fromEnvironment(
    'DOJAH_GOVERNMENT_WIDGET_ID',
  );

  static bool get isStaging => environment == 'staging';
  static bool get isProd => environment == 'prod';
}

final stagingModeProvider = Provider<bool>((ref) => Env.isStaging);

String baseUrl({int version = 1}) => '${Env.baseUrl}/v$version';

/// Whether [value] is an HTTPS service root following the `/api` convention,
/// before the version segment is appended.
bool _isValidServiceRoot(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.isNotEmpty &&
      !value.endsWith('/v1') &&
      !value.contains('/api/api/v1');
}

/// The versioned Core base URL for [configured], or null when it is blank.
///
/// Throws [FormatException] for a configured value that is not a valid
/// service root, so a misconfigured build fails at bootstrap.
String? coreApiBaseUrl(String configured) {
  final value = configured.trim();
  if (value.isEmpty) return null;
  if (!_isValidServiceRoot(value)) {
    throw const FormatException('Invalid CORE_BASE_URL configuration.');
  }
  return '$value/v1';
}

class AppBootstrap {
  const AppBootstrap._();

  static bool initialized = false;

  static void initialize() {
    _validateEnvironment();
    initialized = true;
  }

  static void _validateEnvironment() {
    if (!Env.isStaging && !Env.isProd) {
      throw const FormatException('Invalid ENV configuration.');
    }

    if (!_isValidServiceRoot(Env.baseUrl)) {
      throw const FormatException('Invalid BASE_URL configuration.');
    }
    coreApiBaseUrl(Env.coreBaseUrl);

    if (Env.secureStorageNamespace.trim().isEmpty) {
      throw const FormatException(
        'Invalid SECURE_STORAGE_NAMESPACE configuration.',
      );
    }
  }
}

enum ServiceStatus { idle, loading, success, empty, error, blocked }

class ApiMeta extends Equatable {
  const ApiMeta({this.requestId, this.correlationId, this.extra = const {}});

  factory ApiMeta.fromJson(Object? json) {
    if (json is! Map) return const ApiMeta();
    final map = Map<String, Object?>.from(json);
    final requestId = map.remove('requestId') as String?;
    final correlationId = map.remove('correlationId') as String?;
    return ApiMeta(
      requestId: requestId,
      correlationId: correlationId,
      extra: Map.unmodifiable(map),
    );
  }

  final String? requestId;
  final String? correlationId;
  final Map<String, Object?> extra;

  @override
  List<Object?> get props => [requestId, correlationId, extra];
}

class ServiceResponse<T> extends Equatable {
  const ServiceResponse({
    required this.status,
    this.data,
    this.message,
    this.statusCode,
    this.errorCode,
    this.errors = const [],
    this.meta,
    this.noAuth = false,
  });

  const ServiceResponse.success(
    T data, {
    String? message,
    int? statusCode,
    ApiMeta? meta,
  }) : this(
         status: ServiceStatus.success,
         data: data,
         message: message,
         statusCode: statusCode,
         meta: meta,
       );

  const ServiceResponse.empty({String? message, int? statusCode, ApiMeta? meta})
    : this(
        status: ServiceStatus.empty,
        message: message,
        statusCode: statusCode,
        meta: meta,
      );

  const ServiceResponse.error(
    String message, {
    int? statusCode,
    String? errorCode,
    List<Object?> errors = const [],
    ApiMeta? meta,
    bool noAuth = false,
  }) : this(
         status: ServiceStatus.error,
         message: message,
         statusCode: statusCode,
         errorCode: errorCode,
         errors: errors,
         meta: meta,
         noAuth: noAuth,
       );

  const ServiceResponse.blocked(String message)
    : this(status: ServiceStatus.blocked, message: message);

  final ServiceStatus status;
  final T? data;
  final String? message;
  final int? statusCode;
  final String? errorCode;
  final List<Object?> errors;
  final ApiMeta? meta;
  final bool noAuth;

  bool get isSuccess => status == ServiceStatus.success;
  bool get isBlocked => status == ServiceStatus.blocked;

  @override
  List<Object?> get props => [
    status,
    data,
    message,
    statusCode,
    errorCode,
    errors,
    meta,
    noAuth,
  ];
}

class NotifierState<T> extends Equatable {
  const NotifierState({
    required this.status,
    this.data,
    this.message,
    this.statusCode,
    this.errorCode,
    this.errors = const [],
    this.meta,
    this.noAuth = false,
  });

  const NotifierState.idle({T? data})
    : this(status: ServiceStatus.idle, data: data);
  const NotifierState.loading({T? data})
    : this(status: ServiceStatus.loading, data: data);
  const NotifierState.done(
    T data, {
    String? message,
    int? statusCode,
    ApiMeta? meta,
  }) : this(
         status: ServiceStatus.success,
         data: data,
         message: message,
         statusCode: statusCode,
         meta: meta,
       );
  const NotifierState.empty({String? message, int? statusCode})
    : this(
        status: ServiceStatus.empty,
        message: message,
        statusCode: statusCode,
      );
  const NotifierState.error(
    String message, {
    T? data,
    int? statusCode,
    String? errorCode,
    List<Object?> errors = const [],
    ApiMeta? meta,
    bool noAuth = false,
  }) : this(
         status: ServiceStatus.error,
         data: data,
         message: message,
         statusCode: statusCode,
         errorCode: errorCode,
         errors: errors,
         meta: meta,
         noAuth: noAuth,
       );
  const NotifierState.blocked(String message, {T? data})
    : this(status: ServiceStatus.blocked, data: data, message: message);

  static const _unset = Object();

  final ServiceStatus status;
  final T? data;
  final String? message;
  final int? statusCode;
  final String? errorCode;
  final List<Object?> errors;
  final ApiMeta? meta;
  final bool noAuth;

  bool get isLoading => status == ServiceStatus.loading;
  bool get isDone => status == ServiceStatus.success;
  bool get isError => status == ServiceStatus.error;

  NotifierState<T> copyWith({
    ServiceStatus? status,
    Object? data = _unset,
    Object? message = _unset,
    Object? statusCode = _unset,
    Object? errorCode = _unset,
    List<Object?>? errors,
    Object? meta = _unset,
    bool? noAuth,
  }) {
    return NotifierState<T>(
      status: status ?? this.status,
      data: identical(data, _unset) ? this.data : data as T?,
      message: identical(message, _unset) ? this.message : message as String?,
      statusCode: identical(statusCode, _unset)
          ? this.statusCode
          : statusCode as int?,
      errorCode: identical(errorCode, _unset)
          ? this.errorCode
          : errorCode as String?,
      errors: errors ?? this.errors,
      meta: identical(meta, _unset) ? this.meta : meta as ApiMeta?,
      noAuth: noAuth ?? this.noAuth,
    );
  }

  NotifierState<R> mapData<R>(R? Function(T? data) transform) {
    return NotifierState<R>(
      status: status,
      data: transform(data),
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      errors: errors,
      meta: meta,
      noAuth: noAuth,
    );
  }

  R when<R>({
    required R Function() loading,
    required R Function(T data) done,
    R Function()? idle,
    R Function(String? message)? empty,
    R Function(String message)? error,
    R Function(String message)? blocked,
  }) {
    return switch (status) {
      ServiceStatus.loading => loading(),
      ServiceStatus.success => done(data as T),
      ServiceStatus.empty => empty?.call(message) ?? loading(),
      ServiceStatus.error =>
        error?.call(message ?? 'Something went wrong') ?? loading(),
      ServiceStatus.blocked =>
        blocked?.call(message ?? 'Integration unavailable') ?? loading(),
      ServiceStatus.idle => idle?.call() ?? loading(),
    };
  }

  static NotifierState<T> fromResponse<T>(ServiceResponse<T> response) {
    return NotifierState<T>(
      status: response.status,
      data: response.data,
      message: response.message,
      statusCode: response.statusCode,
      errorCode: response.errorCode,
      errors: response.errors,
      meta: response.meta,
      noAuth: response.noAuth,
    );
  }

  @override
  List<Object?> get props => [
    status,
    data,
    message,
    statusCode,
    errorCode,
    errors,
    meta,
    noAuth,
  ];
}

abstract final class ProcessProvider {
  static void run<T>(
    NotifierState<T> state, {
    void Function(T data)? doneCb,
    void Function(NotifierState<T> state)? errorCb,
    bool showSuccess = false,
    bool showError = true,
  }) {
    switch (state.status) {
      case ServiceStatus.success:
        final data = state.data;
        if (data != null) doneCb?.call(data);
        if (showSuccess && state.message?.isNotEmpty == true) {
          ResponseHandler.showSuccess(state.message!);
        }
      case ServiceStatus.error:
        errorCb?.call(state);
        if (showError && !state.noAuth && state.message?.isNotEmpty == true) {
          ResponseHandler.showError(state.message!);
        }
      case ServiceStatus.blocked:
        errorCb?.call(state);
        if (showError && state.message?.isNotEmpty == true) {
          ResponseHandler.showError(state.message!);
        }
      case ServiceStatus.idle:
      case ServiceStatus.loading:
      case ServiceStatus.empty:
        break;
    }
  }
}

/// Discards results from superseded or disposed async requests.
///
/// Two things can make an in-flight response wrong by the time it lands: a
/// newer request for the same data has already started, or the notifier has
/// been disposed (logout, session expiry, provider invalidation). Writing
/// either result would show stale data or throw.
///
/// Call [trackDisposal] once from `build()`, take a token from [beginRequest]
/// before awaiting, and check [isCurrent] before assigning to `state`.
mixin StaleResultGuard<T> on Notifier<T> {
  int _generation = 0;
  bool _disposed = false;

  /// Registers disposal tracking. Call once from `build()`.
  void trackDisposal() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
  }

  /// Opens a new logical request, superseding any older one still in flight.
  int beginRequest() => ++_generation;

  /// Whether [token] is still the newest request and this notifier is alive.
  bool isCurrent(int token) => !_disposed && token == _generation;
}
