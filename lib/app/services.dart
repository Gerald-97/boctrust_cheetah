import 'package:equatable/equatable.dart';

abstract final class Env {
  static const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://dev-api.boctrustmfb.com/api',
  );
  static const secureStorageKey = String.fromEnvironment('SECURE_STORAGE_KEY');
  static const secureStorageIv = String.fromEnvironment('SECURE_STORAGE_IV');
  static const paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
  );

  static bool get isDev => environment == 'dev';
  static bool get isStaging => environment == 'staging';
  static bool get isProd => environment == 'prod';
}

String baseUrl({int version = 1}) => '${Env.baseUrl}/v$version';

class AppBootstrap {
  const AppBootstrap._();

  static bool initialized = false;

  static void initialize() {
    initialized = true;
  }
}

enum ServiceStatus { idle, loading, success, empty, error, blocked }

class ServiceResponse<T> extends Equatable {
  const ServiceResponse({
    required this.status,
    this.data,
    this.message,
    this.statusCode,
  });

  const ServiceResponse.success(T data, {String? message, int? statusCode})
    : this(
        status: ServiceStatus.success,
        data: data,
        message: message,
        statusCode: statusCode,
      );

  const ServiceResponse.empty({String? message, int? statusCode})
    : this(
        status: ServiceStatus.empty,
        message: message,
        statusCode: statusCode,
      );

  const ServiceResponse.error(String message, {int? statusCode})
    : this(
        status: ServiceStatus.error,
        message: message,
        statusCode: statusCode,
      );

  const ServiceResponse.blocked(String message)
    : this(status: ServiceStatus.blocked, message: message);

  final ServiceStatus status;
  final T? data;
  final String? message;
  final int? statusCode;

  bool get isSuccess => status == ServiceStatus.success;
  bool get isBlocked => status == ServiceStatus.blocked;

  @override
  List<Object?> get props => [status, data, message, statusCode];
}

class NotifierState<T> extends Equatable {
  const NotifierState._({required this.status, this.data, this.message});

  const NotifierState.idle() : this._(status: ServiceStatus.idle);
  const NotifierState.loading() : this._(status: ServiceStatus.loading);
  const NotifierState.done(T data)
    : this._(status: ServiceStatus.success, data: data);
  const NotifierState.empty([String? message])
    : this._(status: ServiceStatus.empty, message: message);
  const NotifierState.error(String message)
    : this._(status: ServiceStatus.error, message: message);
  const NotifierState.blocked(String message)
    : this._(status: ServiceStatus.blocked, message: message);

  final ServiceStatus status;
  final T? data;
  final String? message;

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
      ServiceStatus.empty => empty?.call(message) ?? done(data as T),
      ServiceStatus.error =>
        error?.call(message ?? 'Something went wrong') ?? loading(),
      ServiceStatus.blocked =>
        blocked?.call(message ?? 'Integration unavailable') ?? loading(),
      ServiceStatus.idle => idle?.call() ?? loading(),
    };
  }

  static NotifierState<T> fromResponse<T>(ServiceResponse<T> response) {
    return switch (response.status) {
      ServiceStatus.success =>
        response.data == null
            ? NotifierState<T>.empty(response.message)
            : NotifierState<T>.done(response.data as T),
      ServiceStatus.empty => NotifierState<T>.empty(response.message),
      ServiceStatus.blocked => NotifierState<T>.blocked(
        response.message ?? 'Integration unavailable',
      ),
      ServiceStatus.error => NotifierState<T>.error(
        response.message ?? 'Something went wrong',
      ),
      ServiceStatus.idle => NotifierState<T>.idle(),
      ServiceStatus.loading => NotifierState<T>.loading(),
    };
  }

  @override
  List<Object?> get props => [status, data, message];
}
