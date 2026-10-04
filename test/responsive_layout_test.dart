import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'support/kyc_configuration_fixtures.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:dio/dio.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('PlusJakartaSans');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(
        rootBundle.load('assets/font/PlusJakartaSans-$weight.ttf'),
      );
    }
    await loader.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 1366),
    const Size(1440, 900),
  ]) {
    for (final scale in [1.0, 2.0]) {
      final scenarios = [
        for (final screen in AppScreen.values)
          (screen: screen, route: null, populated: false, keyboard: false),
        for (final route in AppRoutes.allRoutes.where(
          (r) => appPreviewRouteForRoute(r) != null,
        ))
          (
            screen: AppScreen.routePreview,
            route: route,
            populated: false,
            keyboard: false,
          ),
        for (final screen in [
          AppScreen.home,
          AppScreen.account,
          AppScreen.tiers,
          AppScreen.kycIdentity,
          AppScreen.kycGovernmentId,
          AppScreen.kycUtilityBill,
          AppScreen.linkedBanks,
          AppScreen.saveHub,
          AppScreen.flex,
          AppScreen.addMoney,
        ])
          (screen: screen, route: null, populated: true, keyboard: false),
        for (final screen in [
          AppScreen.login,
          AppScreen.createPassword,
          AppScreen.otp,
          AppScreen.createFirstPin,
          AppScreen.kycGovernmentId,
          AppScreen.kycUtilityBill,
        ])
          (screen: screen, route: null, populated: false, keyboard: true),
      ];
      for (final scenario in scenarios) {
        testWidgets('$scenario at $size text $scale', (tester) async {
          final savings =
              [
                AppScreen.saveHub,
                AppScreen.flex,
                AppScreen.target,
                AppScreen.lock,
                AppScreen.group,
                AppScreen.addMoney,
              ].contains(scenario.screen) ||
              scenario.route?.startsWith('/savings/') == true ||
              scenario.route == AppRoutes.bankTransferFunding ||
              scenario.route == AppRoutes.cardFunding;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final preferences = await SharedPreferences.getInstance();
          final dio = Dio(BaseOptions(baseUrl: 'https://layout-test.invalid'));
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                handler.resolve(
                  Response(
                    requestOptions: options,
                    statusCode: 503,
                    data: {'message': 'Unavailable in layout test'},
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
                startupGateProvider.overrideWith(LayoutStartup.new),
                if (savings)
                  authSessionProvider.overrideWith(SavingsSession.new),
                if (savings || scenario.populated)
                  userProfileProvider.overrideWith(LayoutProfile.new),
                if (scenario.populated) ...[
                  userHomeProvider.overrideWith(LayoutHome.new),
                  customerBankAccountsProvider.overrideWith(
                    LayoutCoreAccounts.new,
                  ),
                  coreBankProductsProvider.overrideWith(LayoutCoreProducts.new),
                  userTierProvider.overrideWith(LayoutTiers.new),
                  kycStatusProvider.overrideWith(LayoutKyc.new),
                  kycServiceProvider.overrideWithValue(LayoutKycService()),
                  stagingBuildOverride,
                  bankCatalogueProvider.overrideWith(LayoutBanks.new),
                  withdrawalBankAccountsProvider.overrideWith(
                    LayoutAccounts.new,
                  ),
                ],
              ],
              child: MaterialApp(
                theme: scale == 1
                    ? CheetahTheme.lightTheme
                    : CheetahTheme.darkTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    viewInsets: EdgeInsets.only(
                      bottom: scenario.keyboard ? size.height * .45 : 0,
                    ),
                  ),
                  child: child!,
                ),
                home: AppFlowNavigator(
                  initialScreen: scenario.screen,
                  initialRouteName: scenario.route,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          if (size.width > 840 &&
              find.byType(AppScaffold).evaluate().isNotEmpty) {
            expect(
              tester.getSize(find.byType(Scaffold).first).width,
              size.width,
            );
            final body = tester
                .widget<AppScaffold>(find.byType(AppScaffold))
                .body;
            expect(
              tester.getSize(find.byWidget(body)).width,
              lessThanOrEqualTo(840),
            );
          }
          // Materialize lazy content throughout each page, not only its first view.
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            final state = tester.state<ScrollableState>(scrollables.first);
            for (
              var i = 0;
              i < 80 && state.position.pixels < state.position.maxScrollExtent;
              i++
            ) {
              state.position.jumpTo(
                (state.position.pixels + size.height / 2).clamp(
                  0,
                  state.position.maxScrollExtent,
                ),
              );
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          }
          // Content scrolls under the floating nav pill, so at the end of
          // every scrollable no tap target may be left behind the pill.
          final pill = find.byKey(AppBottomNavigation.pillKey);
          if (!scenario.keyboard && pill.evaluate().isNotEmpty) {
            // Lazy lists only estimate their extent and content may still be
            // settling, so keep jumping to the end until nothing moves.
            for (var pass = 0; pass < 10; pass++) {
              await tester.pump();
              var moved = false;
              for (final element in find.byType(Scrollable).evaluate()) {
                final position =
                    ((element as StatefulElement).state as ScrollableState)
                        .position;
                if (position.axis != Axis.vertical ||
                    position.pixels == position.maxScrollExtent) {
                  continue;
                }
                position.jumpTo(position.maxScrollExtent);
                moved = true;
              }
              if (!moved) break;
            }
            await tester.pump();
            final pillRect = tester.getRect(pill);
            final targets = find.descendant(
              of: find.byWidget(
                tester.widget<AppScaffold>(find.byType(AppScaffold)).body,
              ),
              matching: find.byType(InkWell),
            );
            for (final target in targets.evaluate()) {
              final box = target.renderObject! as RenderBox;
              if (!box.attached || !box.hasSize) continue;
              final rect = box.localToGlobal(Offset.zero) & box.size;
              expect(
                rect.overlaps(pillRect),
                isFalse,
                reason: '${target.widget} at $rect is behind the nav pill',
              );
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
