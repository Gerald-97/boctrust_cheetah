import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/boctrust_transfer_screen.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/interbank_transfer_screen.dart';
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
  final pins = <String>[];

  @override
  Future<ServiceResponse<CoreTransferAck>> transferToBoctrust(
    BoctrustTransferDraft draft, {
    required String transactionPin,
  }) async {
    pins.add(transactionPin);
    return const ServiceResponse.success(
      CoreTransferAck(responseCode: '00', retrievalReference: 'a1b2c3d4e5f6'),
      statusCode: 200,
    );
  }
}

/// Lets the PIN field's blinking cursor run without `pumpAndSettle`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('a transfer is sent once with its PIN, resumes from another '
      'entry, and can be set aside', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transfers = _Transfers();
    var showInterbank = false;
    late StateSetter switchFlow;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SavingsSession.new),
          customerBankAccountsProvider.overrideWith(_Accounts.new),
          coreTransferServiceProvider.overrideWithValue(transfers),
          transferAuthorizationReadyProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: StatefulBuilder(
            builder: (context, setState) {
              switchFlow = setState;
              return showInterbank
                  ? InterbankTransferFlow(
                      onExit: () {},
                      onSectionSelected: (_) {},
                    )
                  : BoctrustTransferFlow(
                      onExit: () {},
                      onSectionSelected: (_) {},
                    );
            },
          ),
        ),
      ),
    );
    await _settle(tester);

    // Account number, then amount.
    await tester.enterText(find.byType(EditableText).at(0), '1100037777');
    await tester.enterText(find.byType(EditableText).at(1), '10');
    await tester.pump();
    await tester.tap(find.text('Review'));
    await _settle(tester);
    await tester.tap(find.textContaining('Send ₦'));
    await _settle(tester);

    await tester.enterText(find.byType(EditableText).last, '0007');
    await tester.pump();
    await tester.tap(find.text('Confirm transfer'));
    await _settle(tester);

    expect(transfers.pins, ['0007']);
    expect(find.text('Transfer processing'), findsOneWidget);

    // Another transfer entry shows the same unresolved transfer.
    switchFlow(() => showInterbank = true);
    await _settle(tester);
    expect(find.text('Transfer processing'), findsOneWidget);
    expect(find.text('Who are you sending to?'), findsNothing);

    await tester.tap(find.text('Start a different transfer'));
    await _settle(tester);
    await tester.tap(find.text('Start anyway'));
    await _settle(tester);
    expect(find.text('Who are you sending to?'), findsOneWidget);
    expect(find.text('Earlier transfer not confirmed'), findsOneWidget);
    expect(transfers.pins, ['0007']);
  });
}
