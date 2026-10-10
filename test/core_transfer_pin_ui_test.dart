import 'dart:async';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/boctrust_transfer_screen.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/core_flow_widgets.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [
        {
          'productCode': 'bocFlex',
          'productName': 'Boc Flex',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': '5000.00',
          'ledgerBalance': '5000.00',
        },
      ],
    }),
  );

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));
  final lookups = <String>[];
  NotifierState<NameEnquiryResult> lookupResult = const NotifierState.done(
    NameEnquiryResult('ADA OBI'),
  );

  /// When set, lookups wait on it instead of answering at once.
  Completer<NotifierState<NameEnquiryResult>>? pending;

  @override
  Future<NotifierState<NameEnquiryResult>> boctrustNameEnquiry(
    String accountNumber,
  ) async {
    lookups.add(accountNumber);
    return pending?.future ?? lookupResult;
  }

  @override
  Future<NotifierState<List<CommercialBank>>> getBanks() async =>
      const NotifierState.done([
        CommercialBank(code: '044', name: 'Access Bank'),
        CommercialBank(code: '058', name: 'GTBank'),
      ]);
}

/// Lets the PIN field's blinking cursor run without `pumpAndSettle`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pumpBoctrust(
  WidgetTester tester,
  _Transfers transfers, {
  String? initialAccountNumber,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await flowTestOverrides(),
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreTransferServiceProvider.overrideWithValue(transfers),
      ],
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: BoctrustTransferFlow(
          onExit: () {},
          onSectionSelected: (_) {},
          initialAccountNumber: initialAccountNumber,
        ),
      ),
    ),
  );
  await _settle(tester);
}

Future<void> _checkAccount(WidgetTester tester, String number) async {
  await tester.enterText(find.byType(EditableText).first, number);
  await tester.pump();
  await tester.tap(find.text('Check account'));
  await _settle(tester);
}

void main() {
  group('BOCTRUST recipient lookup', () {
    testWidgets('a reply for an earlier number is discarded', (tester) async {
      final transfers = _Transfers()..pending = Completer();
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '1100037777');
      await tester.enterText(find.byType(EditableText).first, '1100038888');
      await tester.pump();
      transfers.pending!.complete(
        const NotifierState.done(NameEnquiryResult('ADA OBI')),
      );
      await _settle(tester);

      expect(find.text('ADA OBI'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('changing a digit clears the resolved name', (tester) async {
      await _pumpBoctrust(tester, _Transfers());

      await _checkAccount(tester, '1100037777');
      expect(find.text('ADA OBI'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '1100037778');
      await tester.pump();

      expect(find.text('ADA OBI'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('an unknown account says so', (tester) async {
      final transfers = _Transfers()
        ..lookupResult = const NotifierState.error(
          'Not found',
          statusCode: 404,
        );
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '1100037777');

      expect(find.text(kAccountNotFound), findsOneWidget);
    });

    testWidgets('repeated taps send one lookup', (tester) async {
      final transfers = _Transfers()..pending = Completer();
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '1100037777');
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await _settle(tester);

      expect(transfers.lookups, ['1100037777']);
    });

    testWidgets('a scanned number still needs a lookup', (tester) async {
      final transfers = _Transfers();
      await _pumpBoctrust(
        tester,
        transfers,
        initialAccountNumber: '1100037777',
      );

      expect(transfers.lookups, isEmpty);
      expect(find.text('Check account'), findsOneWidget);
      expect(find.text('Review'), findsNothing);
    });
  });

  testWidgets('a scanned bank code preselects that bank for another bank', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpFlow(
      tester,
      route: AppRoutes.sendOtherBank,
      arguments: const AppRouteArguments(
        entityId: '0123456789',
        bankCode: '058',
      ),
      overrides: [
        featureAvailabilityProvider(
          FeatureCapability.interbankTransfers,
        ).overrideWithValue(FeatureAvailability.available),
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreTransferServiceProvider.overrideWithValue(_Transfers()),
      ],
    );
    await _settle(tester);

    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
  });

  testWidgets('a failed BOCTRUST lookup cannot unlock the amount step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transfers = _Transfers()
      ..lookupResult = const NotifierState.error(
        'Account lookup failed. Try again.',
        data: NameEnquiryResult('ADA OBI'),
        statusCode: 409,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SavingsSession.new),
          customerBankAccountsProvider.overrideWith(_Accounts.new),
          coreTransferServiceProvider.overrideWithValue(transfers),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: BoctrustTransferFlow(onExit: () {}, onSectionSelected: (_) {}),
        ),
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(EditableText).first, '1100037777');
    await tester.pump();
    await tester.tap(find.text('Check account'));
    await _settle(tester);

    expect(find.text('ADA OBI'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Account lookup failed. Try again.'), findsOneWidget);
    expect(find.text('Check account'), findsOneWidget);
  });
}
