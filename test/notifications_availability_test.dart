import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/helper/notification_navigator.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';

void expectNoFabricatedActivity() {
  expect(find.text('Notification history is unavailable'), findsOneWidget);
  for (final text in [
    'Ifeoma',
    '₦412.60',
    '₦35,000',
    '₦150,000',
    'interest credited',
    'Transfer sent',
    'Bank transfer received',
    'Owambe Squad',
    'Group Savings reminder',
    'Today',
    'Yesterday',
  ]) {
    expect(
      find.textContaining(text),
      findsNothing,
      reason: '"$text" presents activity the app never loaded',
    );
  }
  // An empty inbox would also be a claim the app cannot make.
  expect(find.textContaining('No notifications'), findsNothing);
}

void main() {
  testWidgets('the notifications route shows no fabricated activity', (
    tester,
  ) async {
    await pumpFlow(tester, route: AppRoutes.notifications);

    expectNoFabricatedActivity();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home notifications action shows no fabricated activity', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      screen: AppScreen.home,
      route: AppRoutes.home,
      overrides: [
        userProfileProvider.overrideWith(LayoutProfile.new),
        userHomeProvider.overrideWith(LayoutHome.new),
      ],
    );

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump(const Duration(milliseconds: 300));

    expectNoFabricatedActivity();
    expect(tester.takeException(), isNull);
  });

  test('unknown notification routes still fall back to Notifications', () {
    final intent = NotificationNavigator.parse({
      'route': '/not/a/route',
      'id': 'x',
    });
    expect(intent.routeName, AppRoutes.notifications);
  });

  testWidgets('a receipt-targeting notification cannot show a receipt', (
    tester,
  ) async {
    final intent = NotificationNavigator.parse({
      'route': AppRoutes.receipt,
      'id': 'txn-from-push',
    });
    expect(intent.routeName, AppRoutes.receipt);

    await pumpFlow(
      tester,
      route: intent.routeName,
      arguments: AppRouteArguments(entityId: intent.entityId),
    );

    expect(find.text('Transaction receipts are unavailable'), findsOneWidget);
    expect(find.textContaining('successful'), findsNothing);
  });
}
