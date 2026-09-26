import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

void main() {
  testWidgets('real Home request feeds hub, Flex, refresh and bank funding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = savingsSession();
    final requests = <RequestOptions>[];
    var amount = '2500.0000';
    final dio = Dio(BaseOptions(baseUrl: 'https://savings.test/api/v1'));
    dio.interceptors.add(
      AuthInterceptor(
        readAccessToken: () async => session.accessToken,
        readCurrentSession: () => session,
        expireSessionOnce: () async {},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 200,
              data: {
                'success': true,
                'message': 'Loaded',
                'data': {
                  'flexWallet': {
                    'walletId': 'wallet',
                    'walletType': 'bocFlex',
                    'currency': 'NGN',
                    'availableBalance': amount,
                    'ledgerBalance': amount,
                    'status': 'active',
                  },
                  'dedicatedVirtualAccount': {
                    'status': 'available',
                    'bankName': 'Staging Bank',
                    'accountNumber': '0123456789',
                    'accountName': 'Test Customer',
                  },
                  'savingsProducts': [
                    {
                      'code': 'bocFlex',
                      'name': 'Server Flex Product',
                      'walletType': 'bocFlex',
                      'interestRatePerAnnum': '99.99',
                    },
                  ],
                },
              },
            ),
          );
        },
      ),
    );
    addTearDown(() => dio.close(force: true));
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authSessionProvider.overrideWith(SavingsSession.new),
          userProfileProvider.overrideWith(LayoutProfile.new),
          dioProvider.overrideWithValue(dio),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: const AppFlowNavigator(initialScreen: AppScreen.saveHub),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(requests.single.uri.path, '/api/v1/users/me/home');
    expect(requests.single.headers['Authorization'], 'Bearer synthetic-layout');
    expect(find.text('₦2,500.00'), findsWidgets);
    expect(find.text('Server Flex Product'), findsOneWidget);
    expect(find.textContaining('99.99'), findsNothing);

    await tester.tap(find.text('Server Flex Product'));
    await tester.pumpAndSettle();
    expect(
      requests,
      hasLength(1),
      reason: 'Tab/detail navigation shares the Home snapshot.',
    );
    amount = '3000.0000';
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(find.text('₦3,000.00'), findsWidgets);

    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    expect(
      requests,
      hasLength(3),
      reason: 'Funding entry verifies the current DVA.',
    );
    expect(find.text('Staging Bank'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy account number'));
    await tester.tap(find.text('Copy account number'));
    await tester.pumpAndSettle();
    expect(copied, '0123456789');
    expect(requests.every((r) => r.method == 'GET'), isTrue);
  });
}
