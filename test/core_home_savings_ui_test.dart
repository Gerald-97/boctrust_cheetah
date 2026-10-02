import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bank_product_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

Map<String, Object?> _account(
  String code,
  String name,
  String number,
  String balance, {
  String status = 'active',
}) => {
  'productCode': code,
  'productName': name,
  'accountNumber': number,
  'status': status,
  'availableBalance': balance,
  'ledgerBalance': balance,
};

final _accounts = CustomerBankAccountsData.fromJson({
  'totalAvailableBalance': 1,
  'products': [
    _account('bocFlex', 'Boc Flex', '0000000001', '7654.30'),
    _account(
      'regular_savings',
      'Regular Savings',
      '0000000002',
      '100.00',
      status: 'frozen',
    ),
  ],
});

class _Accounts extends CustomerBankAccountsNotifier {
  _Accounts(this.initial);
  final NotifierState<CustomerBankAccountsData> initial;

  @override
  NotifierState<CustomerBankAccountsData> build() => initial;

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

class _Products extends CoreBankProductsNotifier {
  @override
  NotifierState<List<CoreBankProduct>> build() => NotifierState.done(
    CoreBankProduct.listFromJson([
      {'code': 'bocFlex', 'name': 'Boc Flex'},
      {'code': 'regular_savings', 'name': 'Regular Savings'},
      {
        'code': 'fixed_deposit',
        'name': 'Fixed Deposit',
        'description': 'Lock funds for a fixed term.',
      },
    ]),
  );

  @override
  Future<NotifierState<List<CoreBankProduct>>> load() async => state;
}

class _Home extends LayoutHome {
  @override
  Future<NotifierState<UserHomeData>> load() async => state;
}

Future<void> _pump(
  WidgetTester tester,
  AppScreen screen, {
  required NotifierState<CustomerBankAccountsData> accounts,
}) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpFlow(
    tester,
    screen: screen,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      userHomeProvider.overrideWith(_Home.new),
      customerBankAccountsProvider.overrideWith(() => _Accounts(accounts)),
      coreBankProductsProvider.overrideWith(_Products.new),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('Home shows the Core Flex balance beside the User DVA', (
    tester,
  ) async {
    await _pump(
      tester,
      AppScreen.home,
      accounts: NotifierState.done(_accounts),
    );

    expect(find.text('₦7,654.30'), findsOneWidget);
    // LayoutHome's User Service flexWallet balance is never shown.
    expect(find.textContaining('1,234,567,890.12'), findsNothing);
    expect(find.textContaining('0123456789'), findsWidgets);
  });

  testWidgets('a Core failure never falls back to the User balance', (
    tester,
  ) async {
    await _pump(
      tester,
      AppScreen.home,
      accounts: const NotifierState.error('Core is down'),
    );

    expect(find.textContaining('1,234,567,890.12'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
    // Funding details still come from the User Service.
    expect(find.textContaining('0123456789'), findsWidgets);
  });

  testWidgets('Savings lists Core accounts and read-only products', (
    tester,
  ) async {
    await _pump(
      tester,
      AppScreen.saveHub,
      accounts: NotifierState.done(_accounts),
    );

    expect(find.text('Boc Flex'), findsOneWidget);
    expect(find.text('₦7,654.30'), findsOneWidget);
    expect(find.text('Regular Savings'), findsOneWidget);
    expect(find.text('Frozen'), findsOneWidget);
    expect(find.text('Fixed Deposit'), findsOneWidget);
    expect(find.text('Lock funds for a fixed term.'), findsOneWidget);
  });
}
