import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bill_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_bill_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/biometric_overrides.dart';
import 'support/flow_harness.dart';
import 'support/memory_secure_storage.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Bills extends CoreBillService {
  _Bills() : super(null);

  final payments = <(BillPaymentDraft, String)>[];

  /// When set, payments answer with it.
  ServiceResponse<CoreTransferAck>? reply;

  @override
  Future<NotifierState<List<BillerCategory>>> getCategories() async =>
      const NotifierState.done([
        BillerCategory(id: 'cat', name: 'Utility Bills'),
      ]);

  @override
  Future<NotifierState<List<Biller>>> getBillers() async =>
      const NotifierState.done([
        Biller(
          id: 'biller',
          categoryId: 'cat',
          name: 'Power Electric',
          customerFieldLabel: 'Meter Number',
        ),
      ]);

  @override
  Future<NotifierState<List<PaymentItem>>> getPaymentItems() async =>
      const NotifierState.done([
        PaymentItem(
          id: 'item',
          billerId: 'biller',
          name: 'Prepaid',
          amountNaira: '100.00',
        ),
      ]);

  @override
  Future<ServiceResponse<CoreTransferAck>> pay(
    BillPaymentDraft draft, {
    required String transactionPin,
  }) async {
    payments.add((draft, transactionPin));
    if (reply case final reply?) return reply;
    return const ServiceResponse.success(
      CoreTransferAck(
        status: 'Successful',
        responseCode: '00',
        reference: 'BILL-REF',
      ),
    );
  }
}

class _History extends CoreAccountService {
  _History() : super(null);

  final accounts = <String>[];

  @override
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async {
    accounts.add(accountNumber);
    return const NotifierState.done(CoreTransactionPage(rows: []));
  }
}

class _Fingerprint implements BiometricAuthGateway {
  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) async =>
      BiometricAuthOutcome.success;

  @override
  Future<void> stopAuthentication() async {}
}

/// A device enrolled for biometric approval with the saved PIN '0007'.
Future<(BiometricTransferStorage, List<dynamic>)> _enrolled() async {
  final secure = SecureStorage(storage: MemorySecureStorage());
  final login = BiometricLoginStorage(secure);
  final storage = BiometricTransferStorage(secure);
  final recency = AppOpenRecency(secure, login, storage);
  // A first open clears any enrollment, so enroll after it.
  await recency.recordColdLaunch();
  await storage.enable(userId: savingsSession().userId, pin: '0007');
  return (
    storage,
    <dynamic>[
      biometricAuthGatewayProvider.overrideWithValue(_Fingerprint()),
      biometricLoginStorageProvider.overrideWithValue(login),
      biometricTransferStorageProvider.overrideWithValue(storage),
      appOpenRecencyProvider.overrideWithValue(recency),
    ],
  );
}

void main() {
  testWidgets('reviewed bill sends one payment and shows the Core result', (
    tester,
  ) async {
    final bills = _Bills();
    final history = _History();
    await pumpFlow(
      tester,
      route: AppRoutes.billPay,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
        coreBillServiceProvider.overrideWithValue(bills),
        coreAccountServiceProvider.overrideWithValue(history),
        featureAvailabilityProvider(
          FeatureCapability.bills,
        ).overrideWithValue(FeatureAvailability.available),
        ...biometricTestOverrides(),
      ],
    );
    await tester.pump();

    await tester.tap(find.text('Utility Bills'));
    await tester.pump();
    await tester.tap(find.text('Power Electric'));
    await tester.pump();
    await tester.tap(find.text('Prepaid'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump();
    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.tap(find.text('Pay ₦100.00'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Enter your transaction PIN'), findsOneWidget);
    expect(bills.payments, isEmpty);
    await tester.enterText(find.byType(EditableText).last, '0007');
    await tester.pump();
    await tester.tap(find.text('Confirm payment'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(bills.payments, [
      (
        const BillPaymentDraft(
          billerId: 'biller',
          paymentItemId: 'item',
          customerId: '1234567890',
          amountNaira: '100.00',
        ),
        '0007',
      ),
    ]);
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('BILL-REF'), findsOneWidget);
    expect(history.accounts, ['0000000001']);
  });

  testWidgets('canceling the PIN prompt leaves the bill unsubmitted', (
    tester,
  ) async {
    final bills = _Bills();
    await pumpFlow(
      tester,
      route: AppRoutes.billPay,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
        coreBillServiceProvider.overrideWithValue(bills),
        featureAvailabilityProvider(
          FeatureCapability.bills,
        ).overrideWithValue(FeatureAvailability.available),
        ...biometricTestOverrides(),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Utility Bills'));
    await tester.pump();
    await tester.tap(find.text('Power Electric'));
    await tester.pump();
    await tester.tap(find.text('Prepaid'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump();
    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.tap(find.text('Pay ₦100.00'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('Cancel'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(bills.payments, isEmpty);
    expect(find.text('Pay ₦100.00'), findsOneWidget);
    expect(find.text('Payment successful'), findsNothing);
  });

  testWidgets('the biometric sheet pays a bill with the saved PIN', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final bills = _Bills();
    final (storage, biometrics) = await _enrolled();
    await pumpFlow(
      tester,
      route: AppRoutes.billPay,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
        coreBillServiceProvider.overrideWithValue(bills),
        coreAccountServiceProvider.overrideWithValue(_History()),
        featureAvailabilityProvider(
          FeatureCapability.bills,
        ).overrideWithValue(FeatureAvailability.available),
        ...biometrics,
      ],
    );
    await tester.pump();
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    await tester.tap(find.text('Utility Bills'));
    await tester.pump();
    await tester.tap(find.text('Power Electric'));
    await tester.pump();
    await tester.tap(find.text('Prepaid'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump();
    await tester.tap(find.text('Review'));
    await tester.pump();

    // A rejected payment wipes the enrollment and opens the PIN sheet.
    bills.reply = const ServiceResponse.error('No.', statusCode: 400);
    await tester.tap(find.text('Pay ₦100.00'));
    await settle();
    expect(find.byKey(const Key('transaction-pin-sheet')), findsNothing);
    await tester.tap(find.text('Use fingerprint'));
    await settle();
    expect(bills.payments.map((p) => p.$2), ['0007']);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsOneWidget);
    expect(
      find.text(
        'Biometric approval has been turned off. Enter your transaction PIN.',
      ),
      findsOneWidget,
    );
    expect(await storage.loadValidEnrollment(), isNull);
  });

  testWidgets('the biometric sheet sends the bill once and shows the result', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final bills = _Bills();
    final (_, biometrics) = await _enrolled();
    await pumpFlow(
      tester,
      route: AppRoutes.billPay,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
        coreBillServiceProvider.overrideWithValue(bills),
        coreAccountServiceProvider.overrideWithValue(_History()),
        featureAvailabilityProvider(
          FeatureCapability.bills,
        ).overrideWithValue(FeatureAvailability.available),
        ...biometrics,
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Utility Bills'));
    await tester.pump();
    await tester.tap(find.text('Power Electric'));
    await tester.pump();
    await tester.tap(find.text('Prepaid'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '1234567890');
    await tester.pump();
    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.tap(find.text('Pay ₦100.00'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.tap(find.text('Use fingerprint'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(bills.payments.map((p) => p.$2), ['0007']);
    expect(find.text('Payment successful'), findsOneWidget);
  });
}
