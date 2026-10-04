import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/kyc_screens.dart';
import 'package:boctrust_savings_loan/module/onboarding/screens/login_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

void main() {
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
