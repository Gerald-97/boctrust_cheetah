import 'dart:async';
import 'dart:convert';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/auth_flow_listener.dart';
import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/navigators.dart';
import 'package:boctrust_savings_loan/helper/fcm_service.dart';
import 'package:boctrust_savings_loan/helper/local_notification_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_local_notifications.dart';
import 'support/savings_fixtures.dart';

class _FakeFcm implements FCMService {
  RemoteMessage? initial;
  final opened = StreamController<RemoteMessage>.broadcast();

  @override
  Future<RemoteMessage?> getInitialMessage() async {
    final message = initial;
    initial = null;
    return message;
  }

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => opened.stream;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Pushes extends NavigatorObserver {
  final names = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null && name != '/' && name != '/start') names.add(name);
  }
}

String _tap(String route, {String? id}) =>
    jsonEncode({'route': route, 'id': ?id});

void main() {
  late FakeLocalNotificationsPlugin plugin;
  late LocalNotificationService notifications;
  late _FakeFcm fcm;
  late _Pushes pushes;

  setUp(() async {
    plugin = FakeLocalNotificationsPlugin();
    notifications = LocalNotificationService(plugin: plugin, log: (_) {});
    await notifications.initialize();
    fcm = _FakeFcm();
    pushes = _Pushes();
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    bool signedIn = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          fcmServiceProvider.overrideWithValue(fcm),
          localNotificationServiceProvider.overrideWithValue(notifications),
          authSessionProvider.overrideWith(
            signedIn ? SavingsSession.new : SignedOutSavingsSession.new,
          ),
        ],
        child: AuthFlowListener(
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            navigatorObservers: [pushes],
            initialRoute: '/start',
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Text(settings.name ?? ''),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(AuthFlowListener)),
    );
  }

  Future<void> reachHome(WidgetTester tester, ProviderContainer c) async {
    c
        .read(authNavigationProvider.notifier)
        .publish(AuthDestination.home, mode: AuthNavigationMode.clearStack);
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  void localTap(String payload) => plugin.onResponse!(tapResponse(payload));

  List<String> notificationPushes() =>
      pushes.names.where((name) => name != AppRoutes.home).toList();

  testWidgets('a runtime local tap waits for authenticated Home', (
    tester,
  ) async {
    final c = await pumpApp(tester);
    localTap(_tap(AppRoutes.notifications, id: 'n-1'));
    await tester.pump();
    expect(notificationPushes(), isEmpty);
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('a cold-start local tap waits and never replays', (tester) async {
    plugin.launchDetails = NotificationAppLaunchDetails(
      true,
      notificationResponse: tapResponse(_tap(AppRoutes.notifications)),
    );
    var c = await pumpApp(tester);
    await tester.pump();
    expect(notificationPushes(), isEmpty);
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);

    // Recreating the app in the same process must not dispatch it again.
    await tester.pumpWidget(const SizedBox.shrink());
    pushes.names.clear();
    c = await pumpApp(tester);
    await tester.pump();
    await reachHome(tester, c);
    expect(notificationPushes(), isEmpty);
  });

  testWidgets('an FCM background-open tap uses the same queue', (tester) async {
    final c = await pumpApp(tester);
    fcm.opened.add(
      const RemoteMessage(data: {'route': AppRoutes.notifications}),
    );
    await tester.pump();
    expect(notificationPushes(), isEmpty);
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('an FCM cold-start tap uses the same queue', (tester) async {
    fcm.initial = const RemoteMessage(data: {'route': AppRoutes.notifications});
    final c = await pumpApp(tester);
    await tester.pump();
    expect(notificationPushes(), isEmpty);
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('a signed-out tap waits for sign-in and Home', (tester) async {
    final c = await pumpApp(tester, signedIn: false);
    localTap(_tap(AppRoutes.notifications));
    await reachHome(tester, c);
    expect(notificationPushes(), isEmpty);
    (c.read(authSessionProvider.notifier) as SavingsSession).setSession(
      savingsSession(),
    );
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('keeps at most one pending payload', (tester) async {
    final c = await pumpApp(tester);
    localTap(_tap('/unknown-first'));
    localTap(_tap(AppRoutes.notifications, id: 'latest'));
    await tester.pump();
    await reachHome(tester, c);
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('logout clears a pending payload', (tester) async {
    final c = await pumpApp(tester);
    localTap(_tap(AppRoutes.notifications));
    await tester.pump();
    final session = c.read(authSessionProvider.notifier) as SavingsSession;
    session.setSession(null);
    await tester.pump();
    session.setSession(savingsSession());
    await reachHome(tester, c);
    expect(notificationPushes(), isEmpty);
  });

  testWidgets('unknown routes fall back to Notifications', (tester) async {
    final c = await pumpApp(tester);
    await reachHome(tester, c);
    localTap(_tap('/not-a-route'));
    await tester.pump();
    await tester.pump();
    expect(notificationPushes(), [AppRoutes.notifications]);
  });

  testWidgets('works without a notification service', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authSessionProvider.overrideWith(SavingsSession.new)],
        child: const AuthFlowListener(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
