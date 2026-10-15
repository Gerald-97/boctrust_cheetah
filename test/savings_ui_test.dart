import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boctrust_savings_loan/app/app_router.dart';
import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';

void main() {
  testWidgets('funding detail values start in one column', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                ReceiptRow(label: 'Bank', value: 'BocTrust Microfinance Bank'),
                ReceiptRow(label: 'Account number', value: '1100927896'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('BocTrust Microfinance Bank')).dx,
      closeTo(tester.getTopLeft(find.text('1100927896')).dx, 1),
    );
  });

  Future<void> open(WidgetTester tester, String route) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 503,
              data: {'message': 'Test unavailable'},
            ),
          );
        },
      ),
    );
    addTearDown(() => dio.close());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dioProvider.overrideWithValue(dio),
          authSessionProvider.overrideWith(SavingsSession.new),
          userProfileProvider.overrideWith(LayoutProfile.new),
          userHomeProvider.overrideWith(LayoutHome.new),
          customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
          coreBankProductsProvider.overrideWith(LayoutCoreProducts.new),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: appHome(route: route),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Flex shows the live Core balance without sample interest', (
    tester,
  ) async {
    await open(tester, AppRoutes.flexSave);
    expect(find.text('₦1,234,567,890.12'), findsWidgets);
    expect(find.textContaining('12.5%'), findsNothing);
    expect(find.text('Withdraw'), findsNothing);
  });
  for (final screen in [
    AppRoutes.targetSave,
    AppRoutes.lockSave,
    AppRoutes.groupSave,
  ]) {
    testWidgets('$screen is unavailable without money or setup actions', (
      tester,
    ) async {
      await open(tester, screen);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.byType(AppTextField), findsNothing);
      expect(find.text('Back to Savings'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
    });
  }
  testWidgets('funding uses the live virtual account without an amount flow', (
    tester,
  ) async {
    await open(tester, AppRoutes.addMoney);
    expect(find.text('0123456789'), findsOneWidget);
    expect(find.text('Example Merchant Bank'), findsOneWidget);
    expect(find.byType(MoneyKeypad), findsNothing);
    expect(find.text('Continue'), findsNothing);
    final copy = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Copy account number'),
    );
    expect(
      copy.onPressed,
      isNull,
      reason:
          'The funding refresh failed; stale details must not be actionable.',
    );
    expect(
      tester.getTopLeft(find.text('Example Merchant Bank')).dx,
      closeTo(tester.getTopLeft(find.text('0123456789')).dx, 1),
    );
  });

  testWidgets('Account keeps settings without a duplicate Wallet section', (
    tester,
  ) async {
    await open(tester, AppRoutes.account);

    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Wallet'), findsNothing);
    expect(find.text('Dedicated virtual account'), findsNothing);
  });
}
