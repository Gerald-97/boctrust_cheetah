import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/core_api_endpoints.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Unauthorized implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'success': false, 'message': 'Unauthorized'}),
    401,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// Requests `/me/bank-accounts` through [interceptor] against a 401 and
/// reports how many times the session was expired.
Future<int> _expiriesAfter401({required bool expireOnRemote401}) async {
  var expiries = 0;
  final dio = Dio(BaseOptions(baseUrl: 'https://core.example.test/api/v1'))
    ..httpClientAdapter = _Unauthorized()
    ..interceptors.add(
      AuthInterceptor(
        readAccessToken: () async => 'token-1',
        readCurrentSession: () => null,
        expireSessionOnce: () async => expiries++,
        isPublicOperation: (_, _) => false,
        expireSessionOnRemote401: expireOnRemote401,
      ),
    );
  await expectLater(
    dio.get<Object?>(CoreApiEndpoints.bankAccounts),
    throwsA(isA<DioException>()),
  );
  return expiries;
}

void main() {
  group('Core base URL', () {
    test('blank means Core is not configured', () {
      expect(coreApiBaseUrl(''), isNull);
      expect(coreApiBaseUrl('   '), isNull);
    });

    test('follows the User Service /api convention and appends /v1 once', () {
      expect(
        coreApiBaseUrl('https://core-dev-api.centurysoftware.dev/api'),
        'https://core-dev-api.centurysoftware.dev/api/v1',
      );
    });

    test('a configured but invalid value is rejected', () {
      for (final value in [
        'http://core.example.test/api',
        'https://core.example.test/api/v1',
        'https://core.example.test/api/api/v1',
        'not a url',
      ]) {
        expect(
          () => coreApiBaseUrl(value),
          throwsFormatException,
          reason: value,
        );
      }
    });
  });

  test('a Core 401 never expires the User Service session', () async {
    expect(await _expiriesAfter401(expireOnRemote401: false), 0);
    expect(await _expiriesAfter401(expireOnRemote401: true), 1);
  });

  test('mobile banking paths match the Core contract', () {
    expect(
      CoreApiEndpoints.bankAccount('0000000001'),
      '/me/bank-accounts/0000000001',
    );
    expect(CoreApiEndpoints.intrabankWithdrawals, '/me/intrabank/withdrawals');
  });

  test('a Core capability is unavailable until Core is configured', () {
    const operation = (
      backend: ApiBackend.core,
      method: 'GET',
      path: CoreApiEndpoints.bankAccounts,
    );
    expect(
      availabilityFor(
        const CapabilityRequirement(operations: {operation}),
        configuredBackends: const {ApiBackend.user},
      ),
      FeatureAvailability.unavailable,
    );
    expect(
      availabilityFor(
        const CapabilityRequirement(operations: {operation}),
        configuredBackends: const {ApiBackend.user, ApiBackend.core},
      ),
      FeatureAvailability.available,
    );
  });

  test('User capabilities do not depend on Core configuration', () {
    final container = ProviderContainer(
      overrides: [
        configuredApiBackendsProvider.overrideWithValue(const {
          ApiBackend.user,
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(
        featureAvailabilityProvider(FeatureCapability.kycIdentity),
      ),
      FeatureAvailability.available,
    );
  });
}
