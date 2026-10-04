import 'dart:async';

import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/helper/fcm_service.dart';
import 'package:boctrust_savings_loan/module/account/model/profile_image_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/model/withdrawal_bank_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/account/service/withdrawal_bank_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_providers.dart';
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

  group('a response that lands after clear() is discarded', () {
    test('KYC status', () async {
      final kyc = _LateKyc();
      final container = ProviderContainer(
        overrides: [kycServiceProvider.overrideWithValue(kyc)],
      );
      addTearDown(container.dispose);
      final pending = container.read(kycStatusProvider.notifier).load();
      container.read(kycStatusProvider.notifier).clear();
      kyc.status.complete(
        NotifierState.done(
          KycStatusData.fromJson({
            'identity': {'status': 'pending', 'identityLast4': '0006'},
          }),
        ),
      );
      await pending;
      expect(container.read(kycStatusProvider).status, ServiceStatus.idle);
      expect(container.read(kycStatusProvider).data, isNull);
    });

    test('user tier', () async {
      final user = _LateUser();
      final container = ProviderContainer(
        overrides: [userServiceProvider.overrideWithValue(user)],
      );
      addTearDown(container.dispose);
      final pending = container.read(userTierProvider.notifier).load();
      container.read(userTierProvider.notifier).clear();
      user.tier.complete(const NotifierState.error('previous user tier'));
      await pending;
      expect(container.read(userTierProvider).status, ServiceStatus.idle);
    });

    test('profile image signed URL', () async {
      final user = _LateUser();
      final container = ProviderContainer(
        overrides: [userServiceProvider.overrideWithValue(user)],
      );
      addTearDown(container.dispose);
      final pending = container
          .read(profileImageSignedUrlProvider.notifier)
          .ensureLoaded();
      container.read(profileImageSignedUrlProvider.notifier).clear();
      user.signedUrl.complete(
        NotifierState.done(
          ProfileImageSignedUrlData(
            imageUrl: 'https://images.invalid/previous-user.png',
            expiresInSeconds: 300,
          ),
        ),
      );
      await pending;
      expect(container.read(profileImageSignedUrlProvider).data, isNull);
    });

    test('bank catalogue', () async {
      final banks = _LateBanks();
      final container = ProviderContainer(
        overrides: [withdrawalBankServiceProvider.overrideWithValue(banks)],
      );
      addTearDown(container.dispose);
      final pending = container.read(bankCatalogueProvider.notifier).load();
      container.read(bankCatalogueProvider.notifier).clear();
      banks.banks.complete(
        const NotifierState.done(BankCatalogueData(banks: [_gtb])),
      );
      await pending;
      expect(container.read(bankCatalogueProvider).data, isNull);
    });

    test('saved withdrawal accounts', () async {
      final banks = _LateBanks();
      final container = ProviderContainer(
        overrides: [withdrawalBankServiceProvider.overrideWithValue(banks)],
      );
      addTearDown(container.dispose);
      final pending = container
          .read(withdrawalBankAccountsProvider.notifier)
          .load();
      container.read(withdrawalBankAccountsProvider.notifier).clear();
      banks.accounts.complete(
        const NotifierState.done(
          WithdrawalBankAccountListData(
            maxAllowed: 2,
            bankAccounts: [
              WithdrawalBankAccount(
                bankAccountId: 'previous',
                bankCode: '058',
                bankName: 'Guaranty Trust Bank',
                accountNumber: '0123456789',
                accountName: 'Previous User',
              ),
            ],
          ),
        ),
      );
      await pending;
      expect(container.read(withdrawalBankAccountsProvider).data, isNull);
    });

    test('withdrawal account resolution', () async {
      final banks = _LateBanks();
      final container = ProviderContainer(
        overrides: [withdrawalBankServiceProvider.overrideWithValue(banks)],
      );
      addTearDown(container.dispose);
      final draft = container.read(withdrawalBankDraftProvider.notifier)
        ..selectBank(_gtb)
        ..setAccountNumber('0123456789');
      final pending = draft.resolve();
      draft.clear();
      banks.resolution.complete(
        const NotifierState.error('previous user account lookup failed'),
      );
      await pending;
      final state = container.read(withdrawalBankDraftProvider);
      expect(state.status, ServiceStatus.idle);
      expect(state.data, const WithdrawalBankDraft());
    });

    test('government-ID initiation', () async {
      final kyc = _LateKyc();
      final container = ProviderContainer(
        overrides: [kycServiceProvider.overrideWithValue(kyc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        governmentIdVerificationProvider.notifier,
      );
      final pending = notifier.submit(
        documentType: GovernmentIdDocumentType.ninSlip,
      );
      notifier.clear();
      kyc.governmentId.complete(
        const NotifierState.error('previous user initiation failed'),
      );
      await pending;
      final state = container.read(governmentIdVerificationProvider);
      expect(state.status, ServiceStatus.idle);
      expect(state.data, const KycFlowData());
    });

    test('utility-bill upload initiation', () async {
      final kyc = _LateKyc();
      final container = ProviderContainer(
        overrides: [kycServiceProvider.overrideWithValue(kyc)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(utilityBillUploadProvider.notifier)
        ..selectBill(
          const SelectedUtilityBill(
            fileName: 'bill.pdf',
            contentType: 'application/pdf',
            bytes: [1, 2, 3],
          ),
        );
      final pending = notifier.submit(residentialAddress: '1 Broad Street');
      notifier.clear();
      kyc.utilityBill.complete(
        const NotifierState.error('previous user upload failed'),
      );
      await pending;
      final state = container.read(utilityBillUploadProvider);
      expect(state.status, ServiceStatus.idle);
      expect(state.data, const KycFlowData());
    });
  });
}

/// Each service call parks on a completer the test resolves after clear().
class _LateUser extends UserService {
  _LateUser() : super(ApiService(Dio()));
  final tier = Completer<NotifierState<UserTierInfoData>>();
  final signedUrl = Completer<NotifierState<ProfileImageSignedUrlData>>();

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() => tier.future;

  @override
  Future<NotifierState<ProfileImageSignedUrlData>> getProfileImageSignedUrl() =>
      signedUrl.future;
}

class _LateBanks extends WithdrawalBankService {
  _LateBanks() : super(ApiService(Dio()));
  final banks = Completer<NotifierState<BankCatalogueData>>();
  final accounts = Completer<NotifierState<WithdrawalBankAccountListData>>();
  final resolution =
      Completer<NotifierState<ResolveWithdrawalBankAccountData>>();

  @override
  Future<NotifierState<BankCatalogueData>> getBanks() => banks.future;

  @override
  Future<NotifierState<WithdrawalBankAccountListData>> listAccounts() =>
      accounts.future;

  @override
  Future<NotifierState<ResolveWithdrawalBankAccountData>> resolveAccount(
    ResolveWithdrawalBankAccountRequest request,
  ) => resolution.future;
}

class _LateKyc extends KycService {
  _LateKyc() : super(ApiService(Dio()));
  final status = Completer<NotifierState<KycStatusData>>();
  final governmentId = Completer<NotifierState<KycInitiationData>>();
  final utilityBill = Completer<NotifierState<UtilityBillUploadTarget>>();

  @override
  Future<NotifierState<KycStatusData>> getStatus() => status.future;

  @override
  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) => governmentId.future;

  @override
  Future<NotifierState<UtilityBillUploadTarget>> initiateUtilityBillUpload(
    UtilityBillInitiationRequest request,
  ) => utilityBill.future;
}

const _gtb = BankData(name: 'Guaranty Trust Bank', code: '058');
