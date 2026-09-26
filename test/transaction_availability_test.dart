import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

/// Text that only a simulated transaction could produce. None of it may appear
/// while no transaction service exists.
const _fabricated = <String>[
  // Success and receipt copy.
  'Transfer successful',
  'Money moved successfully',
  'Airtime purchase successful',
  'Data purchase successful',
  'Bill payment successful',
  'BOC7734912X',
  'Share receipt',
  // Fixed recipients, resolutions, and activity.
  'Ifeoma',
  'Tunde Bakare',
  'Chuka Obi',
  'Hauwa Musa',
  'Adaeze Okonkwo',
  'Account name resolved',
  'Prepaid meter confirmed',
  '0803 214 7756',
  '04521187733',
  '₦35,000',
  '₦2,000',
  '₦15,000',
  // Controls that implied the operation would run.
  'Confirm & complete transaction',
  'Use Face ID or fingerprint instead',
  'Enter your PIN',
  'Enter code manually',
  "Point your camera at a merchant's QR code to pay instantly",
  'Review transfer',
  'Move money',
  'Buy airtime',
  'Buy data bundle',
  'Pay bill',
  'Preview receipt',
  'Preview return to app',
  'Preview beneficiary setup',
  'No transactions yet',
];

void expectNothingFabricated() {
  for (final text in _fabricated) {
    expect(
      find.textContaining(text),
      findsNothing,
      reason: '"$text" describes a transaction that never happened',
    );
  }
}

void main() {
  final unavailable = <String, String>{
    AppRoutes.sendOwnAccount: 'Transfers are unavailable',
    AppRoutes.sendBeneficiary: 'Transfers are unavailable',
    AppRoutes.sendOtherBank: 'Transfers are unavailable',
    AppRoutes.airtime: 'Airtime purchases are unavailable',
    AppRoutes.data: 'Data purchases are unavailable',
    AppRoutes.billerListElectricity: 'Bill payments are unavailable',
    AppRoutes.billerListWater: 'Bill payments are unavailable',
    AppRoutes.billerListCable: 'Bill payments are unavailable',
    AppRoutes.billerListInternet: 'Bill payments are unavailable',
    AppRoutes.billerListEducation: 'Bill payments are unavailable',
    AppRoutes.billerListMore: 'Bill payments are unavailable',
    AppRoutes.billPay: 'Bill payments are unavailable',
    AppRoutes.scanToPay: 'Scan to pay is unavailable',
    AppRoutes.transactionAuthorization:
        'Transaction authorization is unavailable',
    AppRoutes.receipt: 'Transaction receipts are unavailable',
    AppRoutes.transactionHistory: 'Transaction history is unavailable',
    AppRoutes.paymentWebView: 'Payment checkout is unavailable',
    AppRoutes.manageBeneficiaries: 'Beneficiaries are unavailable',
  };

  for (final MapEntry(key: route, value: title) in unavailable.entries) {
    for (final arguments in const [
      AppRouteArguments(),
      // A notification or deep link must not turn an identifier into a receipt.
      AppRouteArguments(entityId: 'unverified-id'),
    ]) {
      testWidgets('$route is honestly unavailable '
          '(entityId: ${arguments.entityId})', (tester) async {
        await pumpFlow(tester, route: route, arguments: arguments);

        expect(find.text(title), findsOneWidget);
        expect(
          find.byType(EditableText),
          findsNothing,
          reason: 'an unavailable operation must not collect payment input',
        );
        expectNothingFabricated();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the authorization route has no PIN pad or bypass controls', (
    tester,
  ) async {
    await pumpFlow(tester, route: AppRoutes.transactionAuthorization);

    expect(
      find.text('Transaction authorization is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Confirm & complete transaction'), findsNothing);
    expect(find.text('Use Face ID or fingerprint instead'), findsNothing);
    expect(find.text('Transfer successful'), findsNothing);
    expect(find.text('BOC7734912X'), findsNothing);
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);

    // Waiting past the former auto-complete delay must not produce a receipt.
    await tester.pump(const Duration(seconds: 1));
    expectNothingFabricated();
  });

  testWidgets('Send hub lists no sample recipients', (tester) async {
    await pumpFlow(tester, route: AppRoutes.sendHub);

    expect(find.text('Recent recipients'), findsNothing);
    expectNothingFabricated();

    await tester.tap(find.text('To another bank'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Transfers are unavailable'), findsOneWidget);
    expectNothingFabricated();
  });

  testWidgets('Pay hub shows no sample activity', (tester) async {
    await pumpFlow(tester, route: AppRoutes.paymentsHub);

    expect(find.text('Recent transactions'), findsNothing);
    expectNothingFabricated();

    await tester.scrollUntilVisible(
      find.text('Electricity'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear the bottom navigation bar so the tap lands on the tile.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.text('Electricity'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Bill payments are unavailable'), findsOneWidget);
    expectNothingFabricated();
  });

  testWidgets('Pay hub Add money opens the live funding screen', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      route: AppRoutes.paymentsHub,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        userProfileProvider.overrideWith(LayoutProfile.new),
        userHomeProvider.overrideWith(LayoutHome.new),
      ],
    );

    await tester.tap(find.text('Add money'));
    // The Savings access gate prepares on a post-frame callback.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(find.widgetWithText(AppBar, 'Add money'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(tester.takeException(), isNull);

    // Let the funding screen's load settle before the binding checks timers.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
