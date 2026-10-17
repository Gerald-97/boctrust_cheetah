import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/account_freeze_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
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

class _FreezeSpy extends AccountFreezeController {
  _FreezeSpy(super.accountNumber);

  static final calls = <(String, String)>[];

  @override
  Future<void> freeze(String transactionPin) async =>
      calls.add((accountNumber, transactionPin));
}

void main() {
  testWidgets('freezing an active account collects the PIN for that account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _FreezeSpy.calls.clear();
    await pumpFlow(
      tester,
      route: AppRoutes.securitySettings,
      overrides: [
        // The private route's gate needs a session and a profile.
        authSessionProvider.overrideWith(SavingsSession.new),
        userProfileProvider.overrideWith(LayoutProfile.new),
        featureAvailabilityProvider(
          FeatureCapability.freezeAccount,
        ).overrideWithValue(FeatureAvailability.available),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        accountFreezeProvider.overrideWith2(_FreezeSpy.new),
      ],
    );

    await tester.ensureVisible(find.text('Freeze an account'));
    await tester.tap(find.text('Freeze an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SecondaryButton, 'Freeze account'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    // The focused PIN field blinks its caret, so it never settles.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(_FreezeSpy.calls, isEmpty, reason: 'no PIN, no freeze');

    await tester.enterText(find.byType(EditableText).last, '1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Freeze account'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(_FreezeSpy.calls, [('0000000001', '1234')]);
  });
}
