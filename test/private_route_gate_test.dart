import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/kyc_screens.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/login_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _NoPinProfile extends LayoutProfile {
  @override
  NotifierState<UserOwnProfileData> build() =>
      NotifierState.done(super.build().data!.copyWith(isCreatedPin: false));
}

void main() {
  testWidgets('a signed-in Home link still requires first PIN setup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SavingsSession.new),
          userProfileProvider.overrideWith(_NoPinProfile.new),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: (_) => [
            AppRouter.onGenerateRoute(
              const RouteSettings(name: AppRoutes.home),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Create your transaction PIN'), findsOneWidget);
  });

  testWidgets('a signed-out deep link to a private route lands on login', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SignedOutSavingsSession.new),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onGenerateInitialRoutes: (_) => [
            AppRouter.onGenerateRoute(
              const RouteSettings(name: AppRoutes.tierOverview),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(KycTiersScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
