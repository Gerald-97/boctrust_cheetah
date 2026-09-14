import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

void main() {
  for (final route in [
    AppRoutes.loansComingSoon,
    AppRoutes.loansNotifyMe,
    AppRoutes.cardsComingSoon,
    AppRoutes.cardsNotifyMe,
  ]) {
    testWidgets('$route promises no launch notification', (tester) async {
      await pumpFlow(tester, route: route);

      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text("Notify me when it's ready"), findsNothing);
      expect(
        find.text('Launch notifications are not available yet.'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
      expect(find.textContaining('You will be notified'), findsNothing);
      expect(find.textContaining("We'll let you know"), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
