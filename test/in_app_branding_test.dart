import 'package:boctrust_savings_loan/app/bootstrap_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/preferences.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/kyc_configuration_fixtures.dart';
import 'support/responsive_fixtures.dart';

const _markAsset = 'assets/branding/cheetah_app_icon.svg';

final _themes = {
  'light': CheetahTheme.lightTheme,
  'dark': CheetahTheme.darkTheme,
  'high-contrast light': CheetahTheme.theme(
    Brightness.light,
    highContrast: true,
  ),
  'high-contrast dark': CheetahTheme.theme(Brightness.dark, highContrast: true),
};

String _assetOf(WidgetTester tester, Finder svg) {
  final loader = tester.widget<SvgPicture>(svg).bytesLoader;
  expect(loader, isA<SvgAssetLoader>());
  return (loader as SvgAssetLoader).assetName;
}

Finder _inLogo(Finder finder) =>
    find.descendant(of: find.byType(BocLogo), matching: finder);

void main() {
  group('BocBrandMark', () {
    testWidgets('renders the approved SVG at the requested square size', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: BocBrandMark(size: 42))),
      );
      final svg = find.byType(SvgPicture);
      expect(svg, findsOneWidget);
      expect(_assetOf(tester, svg), _markAsset);
      expect(tester.widget<SvgPicture>(svg).colorFilter, isNull);
      expect(tester.getSize(find.byType(BocBrandMark)), const Size(42, 42));
    });

    testWidgets('is decorative unless given a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              BocBrandMark(size: 30),
              BocBrandMark(size: 30, semanticLabel: 'BOCTRUST'),
            ],
          ),
        ),
      );
      expect(find.bySemanticsLabel('BOCTRUST'), findsOneWidget);
      handle.dispose();
    });
  });

  group('BocLogo', () {
    for (final MapEntry(key: name, value: theme) in _themes.entries) {
      for (final height in [26.0, 36.0, 42.0, 52.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets('$name at $height text $scale', (tester) async {
            final handle = tester.ensureSemantics();
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(width: 220, child: BocLogo(height: height)),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            final svg = _inLogo(find.byType(SvgPicture));
            expect(svg, findsOneWidget);
            expect(_assetOf(tester, svg), _markAsset);
            expect(tester.getSize(svg).height, height);
            expect(_inLogo(find.byIcon(Icons.savings_rounded)), findsNothing);
            expect(_inLogo(find.text('BOCTRUST')), findsOneWidget);
            expect(find.bySemanticsLabel('BOCTRUST'), findsOneWidget);
            handle.dispose();
          });
        }
      }
    }
  });

  group('app identity surfaces', () {
    for (final (screen, populated) in [
      (AppScreen.bootstrap, false),
      (AppScreen.onboarding, false),
      (AppScreen.login, false),
      (AppScreen.home, true),
    ]) {
      testWidgets('$screen shows the shared brand mark', (tester) async {
        await _pumpScreen(tester, screen, populated: populated);
        expect(tester.takeException(), isNull);
        final svg = _inLogo(find.byType(SvgPicture));
        expect(svg, findsOneWidget);
        expect(_assetOf(tester, svg), _markAsset);
        expect(_inLogo(find.byIcon(Icons.savings_rounded)), findsNothing);
        if (screen == AppScreen.home) {
          // The Save destination is a product icon, not app identity.
          expect(find.byIcon(Icons.savings_outlined), findsWidgets);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  AppScreen screen, {
  required bool populated,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final dio = Dio(BaseOptions(baseUrl: 'https://branding-test.invalid'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 503,
          data: {'message': 'Unavailable in branding test'},
        ),
      ),
    ),
  );
  addTearDown(() => dio.close());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        dioProvider.overrideWithValue(dio),
        startupGateProvider.overrideWith(LayoutStartup.new),
        if (populated) ...[
          userProfileProvider.overrideWith(LayoutProfile.new),
          userHomeProvider.overrideWith(LayoutHome.new),
          customerBankAccountsProvider.overrideWith(LayoutCoreAccounts.new),
          coreBankProductsProvider.overrideWith(LayoutCoreProducts.new),
          userTierProvider.overrideWith(LayoutTiers.new),
          kycStatusProvider.overrideWith(LayoutKyc.new),
          kycServiceProvider.overrideWithValue(LayoutKycService()),
          stagingBuildOverride,
          bankCatalogueProvider.overrideWith(LayoutBanks.new),
          withdrawalBankAccountsProvider.overrideWith(LayoutAccounts.new),
        ],
      ],
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: AppFlowNavigator(initialScreen: screen),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
