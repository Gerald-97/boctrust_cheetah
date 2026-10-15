import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class NoPinProfile extends LayoutProfile {
  @override
  NotifierState<UserOwnProfileData> build() =>
      NotifierState.done(super.build().data!.copyWith(isCreatedPin: false));
}

void main() {
  testWidgets(
    'system Back cannot leave Savings while profile access is pending',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final requests = <RequestOptions>[];
      final handlers = <RequestInterceptorHandler>[];
      final dio = Dio(BaseOptions(baseUrl: 'https://savings.test/api/v1'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handlers.add(handler);
          },
        ),
      );
      addTearDown(() => dio.close(force: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            dioProvider.overrideWithValue(dio),
            authSessionProvider.overrideWith(SavingsSession.new),
          ],
          child: MaterialApp(
            theme: CheetahTheme.lightTheme,
            onGenerateRoute: AppRouter.onGenerateRoute,
            initialRoute: AppRoutes.savingsHub,
            onGenerateInitialRoutes: (_) => [
              AppRouter.onGenerateRoute(
                const RouteSettings(name: AppRoutes.savingsHub),
              ),
            ],
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.binding.handlePopRoute();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final reachedHome = find.textContaining('Hi, ').evaluate().isNotEmpty;
      final paths = requests.map((request) => request.path).toList();
      for (var i = 0; i < handlers.length; i++) {
        handlers[i].resolve(
          Response(
            requestOptions: requests[i],
            statusCode: 503,
            data: {'success': false, 'message': 'Unavailable'},
          ),
        );
      }
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(reachedHome, isFalse);
      expect(paths, ['/users/me/profile']);
    },
  );

  Future<void> open(
    WidgetTester tester,
    String route, {
    bool signedIn = true,
    bool pin = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 503,
              data: {'success': false, 'message': 'Unavailable'},
            ),
          );
        },
      ),
    );
    addTearDown(() => dio.close(force: true));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          dioProvider.overrideWithValue(dio),
          authSessionProvider.overrideWith(
            signedIn ? SavingsSession.new : SignedOutSavingsSession.new,
          ),
          userProfileProvider.overrideWith(
            pin ? LayoutProfile.new : NoPinProfile.new,
          ),
          userHomeProvider.overrideWith(LayoutHome.new),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: route,
          onGenerateInitialRoutes: (_) => [
            AppRouter.onGenerateRoute(RouteSettings(name: route)),
          ],
        ),
      ),
    );
    // PIN fields animate their cursor continuously; settle finite async work.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'direct Savings entry cannot render cached private data signed out',
    (tester) async {
      await open(tester, AppRoutes.flexSave, signedIn: false);
      expect(find.text('₦1,234,567,890.12'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    },
  );
  testWidgets('direct Savings entry enforces first PIN', (tester) async {
    await open(tester, AppRoutes.flexSave, pin: false);
    expect(find.text('₦1,234,567,890.12'), findsNothing);
    expect(find.text('Create your transaction PIN'), findsOneWidget);
  });
  testWidgets('cold Savings child Back returns to hub', (tester) async {
    await open(tester, AppRoutes.flexSave);
    await tester.tap(find.byType(BocBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Your savings'), findsOneWidget);
  });
  for (final route in [
    AppRoutes.newSavingsChooser,
    AppRoutes.flexWithdraw,
    AppRoutes.flexStatement,
    AppRoutes.flexSettings,
    AppRoutes.targetSaveCreate,
    AppRoutes.targetSort,
    AppRoutes.lockCreate,
    AppRoutes.lockDetails,
    AppRoutes.lockAddMoney,
    AppRoutes.groupCreate,
    AppRoutes.groupContribute,
    AppRoutes.groupInvite,
    AppRoutes.groupMembers,
    AppRoutes.cardFunding,
  ]) {
    testWidgets('$route cannot expose a simulated financial action', (
      tester,
    ) async {
      await open(tester, route);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.textContaining('₦'), findsNothing);
      expect(find.byType(AppTextField), findsNothing);
    });
  }
}
