import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bill_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_bill_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Bills extends CoreBillService {
  _Bills() : super(null);

  final payments = <(BillPaymentDraft, String)>[];

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
    return const ServiceResponse.success(
      CoreTransferAck(
        status: 'Successful',
        responseCode: '00',
        reference: 'BILL-REF',
      ),
    );
  }
}

void main() {
  testWidgets('reviewed bill sends one payment and shows the Core result', (
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
}
