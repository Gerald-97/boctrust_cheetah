import 'dart:async';

import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/helper/fcm_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_configuration_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/security_action_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

class _Kyc extends KycService {
  _Kyc() : super(ApiService(Dio()));

  @override
  Future<NotifierState<KycStatusData>> getStatus() async => NotifierState.done(
    KycStatusData.fromJson({
      'identity': {'status': 'pending', 'identityLast4': '0006'},
    }),
  );

  @override
  Future<NotifierState<GovernmentIdDocumentCatalogue>>
  getGovernmentIdDocumentTypes() async => NotifierState.done(
    GovernmentIdDocumentCatalogue.fromJson({
      'documentTypes': [
        {
          'value': 'national_id',
          'label': 'National ID',
          'description': '',
          'requiresDocumentNumber': false,
          'active': true,
        },
      ],
    }),
  );
}

class _Accounts extends CoreAccountService {
  _Accounts() : super(ApiService(Dio()));

  @override
  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() async =>
      NotifierState.done(
        CustomerBankAccountsData.fromJson({
          'products': [
            {
              'productCode': 'bocFlex',
              'productName': 'Flex',
              'accountNumber': '0000000001',
              'status': 'active',
              'availableBalance': '10.00',
            },
          ],
        }),
      );
}

class _Fcm implements FCMService {
  _Fcm(this._delete);
  final Future<void> Function() _delete;
  var deleteCalls = 0;

  @override
  Future<void> deleteToken() {
    deleteCalls++;
    return _delete();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _signedIn({required _Fcm fcm, bool firebaseReady = true}) =>
    ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        firebaseReadyProvider.overrideWithValue(firebaseReady),
        fcmServiceProvider.overrideWithValue(fcm),
        dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://logout-test.invalid'))
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) => handler.resolve(
                  Response(requestOptions: options, statusCode: 200, data: {}),
                ),
              ),
            ),
        ),
      ],
    );

void _expectSignedOut(ProviderContainer container) {
  expect(container.read(authSessionProvider), isNull);
  expect(
    container.read(authNavigationProvider).last.destination,
    AuthDestination.login,
  );
}

void main() {
  group('FCM token on logout', () {
    test(
      'deletes the device token so the old account stops receiving',
      () async {
        final fcm = _Fcm(() async {});
        final container = _signedIn(fcm: fcm);
        addTearDown(container.dispose);
        await container.read(logoutProvider.notifier).logout();
        expect(fcm.deleteCalls, 1);
        _expectSignedOut(container);
      },
    );

    test('a failing delete never interrupts logout', () async {
      final fcm = _Fcm(() async => throw Exception('firebase unavailable'));
      final container = _signedIn(fcm: fcm);
      addTearDown(container.dispose);
      await expectLater(
        container.read(logoutProvider.notifier).logout(),
        completes,
      );
      await pumpEventQueue();
      _expectSignedOut(container);
    });

    test(
      'a delete that throws synchronously never interrupts logout',
      () async {
        final fcm = _Fcm(() => throw StateError('no messaging instance'));
        final container = _signedIn(fcm: fcm);
        addTearDown(container.dispose);
        await container.read(logoutProvider.notifier).logout();
        _expectSignedOut(container);
      },
    );

    test('a delete that never finishes does not hold logout', () async {
      final fcm = _Fcm(() => Completer<void>().future);
      final container = _signedIn(fcm: fcm);
      addTearDown(container.dispose);
      await container.read(logoutProvider.notifier).logout();
      _expectSignedOut(container);
    });

    test('is skipped when Firebase is not configured', () async {
      final fcm = _Fcm(() async {});
      final container = _signedIn(fcm: fcm, firebaseReady: false);
      addTearDown(container.dispose);
      await container.read(logoutProvider.notifier).logout();
      expect(fcm.deleteCalls, 0);
      _expectSignedOut(container);
    });
  });

  test('logging out drops the previous user KYC status', () async {
    final container = ProviderContainer(
      overrides: [kycServiceProvider.overrideWithValue(_Kyc())],
    );
    addTearDown(container.dispose);
    await container.read(kycStatusProvider.notifier).load();
    expect(
      container.read(kycStatusProvider).data?.identity.identityLast4,
      '0006',
    );

    await container.read(logoutProvider.notifier).logout();

    expect(container.read(kycStatusProvider).data, isNull);
  });

  test('logging out drops the government-ID document catalogue', () async {
    final container = ProviderContainer(
      overrides: [kycServiceProvider.overrideWithValue(_Kyc())],
    );
    addTearDown(container.dispose);
    await container.read(governmentIdDocumentTypesProvider.notifier).load();
    expect(container.read(governmentIdDocumentTypesProvider).data, isNotNull);

    await container.read(logoutProvider.notifier).logout();

    expect(container.read(governmentIdDocumentTypesProvider).data, isNull);
  });

  test('logging out drops the previous user Core balances', () async {
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        coreAccountServiceProvider.overrideWithValue(_Accounts()),
        // The server logout call fails; local clearing must still happen.
        dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://logout-test.invalid'))
            ..interceptors.add(
              InterceptorsWrapper(
                onRequest: (options, handler) => handler.resolve(
                  Response(requestOptions: options, statusCode: 503),
                ),
              ),
            ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(customerBankAccountsProvider.notifier).load();
    expect(container.read(customerBankAccountsProvider).data, isNotNull);

    await container.read(logoutProvider.notifier).logout();

    expect(container.read(customerBankAccountsProvider).data, isNull);
  });
}
