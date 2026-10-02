import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/core_network.dart';
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

/// A Dio on [baseUrl] that authenticates like production and answers every
/// request from [respond].
Dio _dio(
  String baseUrl,
  List<RequestOptions> requests,
  Object? Function(RequestOptions request) respond, {
  required String token,
  bool core = false,
}) {
  final session = savingsSession();
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  dio.interceptors.add(
    AuthInterceptor(
      readAccessToken: () async => token,
      readCurrentSession: () => session,
      expireSessionOnce: () async {},
      isPublicOperation: core ? (_, _) => false : ApiEndpoints.isPublic,
      expireSessionOnRemote401: !core,
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
              'data': respond(request),
            },
          ),
        );
      },
    ),
  );
  addTearDown(() => dio.close(force: true));
  return dio;
}

void main() {
  testWidgets('Core feeds the hub, Flex and refresh; User Home feeds funding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final token = savingsSession().accessToken;
    final userRequests = <RequestOptions>[];
    final coreRequests = <RequestOptions>[];
    var amount = '2500.0000';

    final userDio = _dio(
      'https://savings.test/api/v1',
      userRequests,
      (_) => {
        'flexWallet': {
          'currency': 'NGN',
          'availableBalance': '1.00',
          'status': 'active',
        },
        'dedicatedVirtualAccount': {
          'status': 'available',
          'bankName': 'Staging Bank',
          'accountNumber': '0123456789',
          'accountName': 'Test Customer',
        },
      },
      token: token,
    );
    final coreDio = _dio(
      'https://core.test/api/v1',
      coreRequests,
      (request) {
        final flex = {
          'productCode': 'bocFlex',
          'productName': 'Server Flex Product',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': amount,
          'ledgerBalance': amount,
        };
        return switch (request.path) {
          '/bank-products' => [
            {
              'code': 'bocFlex',
              'name': 'Server Flex Product',
              'interestRate': 99.99,
            },
          ],
          // Flex refresh reads just its own account.
          '/me/bank-accounts/0000000001' => flex,
          _ => {
            'totalAvailableBalance': 99.99,
            'products': [flex],
          },
        };
      },
      token: token,
      core: true,
    );

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
          dioProvider.overrideWithValue(userDio),
          coreDioProvider.overrideWithValue(coreDio),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: const AppFlowNavigator(initialScreen: AppScreen.saveHub),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(coreRequests.map((r) => r.uri.toString()).toSet(), {
      'https://core.test/api/v1/me/bank-accounts',
      'https://core.test/api/v1/bank-products',
    });
    expect(coreRequests.map((r) => r.headers['Authorization']).toSet(), {
      'Bearer $token',
    });
    expect(find.text('₦2,500.00'), findsWidgets);
    expect(find.text('Server Flex Product'), findsOneWidget);
    expect(find.textContaining('99.99'), findsNothing);
    expect(find.text('₦1.00'), findsNothing);

    await tester.tap(find.text('Server Flex Product'));
    await tester.pumpAndSettle();
    final coreAfterHub = coreRequests.length;
    amount = '3000.0000';
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(coreRequests.length, greaterThan(coreAfterHub));
    expect(find.text('₦3,000.00'), findsWidgets);

    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    expect(
      userRequests.map((r) => r.uri.toString()),
      contains('https://savings.test/api/v1/users/me/home'),
      reason: 'Funding still comes from the User Service.',
    );
    expect(find.text('Staging Bank'), findsOneWidget);
    await tester.ensureVisible(find.text('Copy account number'));
    await tester.tap(find.text('Copy account number'));
    await tester.pumpAndSettle();
    expect(copied, '0123456789');
    expect(
      [...userRequests, ...coreRequests].every((r) => r.method == 'GET'),
      isTrue,
    );
  });
}
