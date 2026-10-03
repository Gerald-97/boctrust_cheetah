import 'dart:convert';

import 'package:boctrust_savings_loan/helper/local_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_local_notifications.dart';

const _secretMessage = RemoteMessage(
  messageId: 'msg-1',
  data: {'route': '/notifications', 'id': 'n-1', 'balance': '₦99,000'},
  notification: RemoteNotification(
    title: 'Ada, your balance is ₦99,000',
    body: 'Account 0123456789 credited',
  ),
);

void main() {
  late FakeLocalNotificationsPlugin plugin;
  late List<String> logs;
  late LocalNotificationService service;

  setUp(() {
    plugin = FakeLocalNotificationsPlugin();
    logs = [];
    service = LocalNotificationService(plugin: plugin, log: logs.add);
  });

  group('initialize', () {
    test('uses the BOCTRUST icon, requests no Darwin permissions', () async {
      expect(await service.initialize(), isTrue);
      final settings = plugin.initializations.single;
      expect(
        settings.android!.defaultIcon,
        LocalNotificationService.androidSmallIcon,
      );
      final darwin = settings.iOS!;
      expect(darwin.requestAlertPermission, isFalse);
      expect(darwin.requestBadgePermission, isFalse);
      expect(darwin.requestSoundPermission, isFalse);
    });

    test('creates the high-importance channel once', () async {
      await service.initialize();
      await service.initialize();
      expect(plugin.initializations, hasLength(1));
      final channel = plugin.android.channels.single;
      expect(channel.id, 'boctrust_general');
      expect(channel.name, 'BOCTRUST notifications');
      expect(channel.importance, Importance.high);
    });

    test('a failure returns false without throwing, and can retry', () async {
      plugin.initializeError = StateError('plugin unavailable');
      expect(await service.initialize(), isFalse);
      plugin.initializeError = null;
      expect(await service.initialize(), isTrue);
    });
  });

  group('showRemoteMessage', () {
    test('shows generic copy with the normalized id and payload', () async {
      await service.showRemoteMessage(_secretMessage);
      final shown = plugin.shown.single;
      expect(shown.title, 'BOCTRUST');
      expect(shown.body, 'You have a new notification.');
      expect(shown.id, inInclusiveRange(1, 0x7fffffff));
      expect(jsonDecode(shown.payload!), {
        'route': '/notifications',
        'id': 'n-1',
      });
      final android = shown.details!.android!;
      expect(android.channelId, 'boctrust_general');
      expect(android.channelName, 'BOCTRUST notifications');
      expect(android.importance, Importance.high);
      expect(android.priority, Priority.high);
      expect(android.icon, LocalNotificationService.androidSmallIcon);
      expect(shown.details!.iOS, isNotNull);
    });

    test('skips messages with nothing to display', () async {
      await service.showRemoteMessage(const RemoteMessage(data: {'x': 'y'}));
      expect(plugin.shown, isEmpty);
    });

    test('swallows display failures and logs no remote content', () async {
      plugin.showError = Exception(
        'boom ${_secretMessage.notification!.title}',
      );
      await expectLater(service.showRemoteMessage(_secretMessage), completes);
      expect(logs, isNotEmpty);
      for (final line in logs) {
        expect(line, isNot(contains('Ada')));
        expect(line, isNot(contains('99,000')));
        expect(line, isNot(contains('0123456789')));
        expect(line, isNot(contains('n-1')));
      }
    });

    test('does not show when initialization fails', () async {
      plugin.initializeError = StateError('plugin unavailable');
      await expectLater(service.showRemoteMessage(_secretMessage), completes);
      expect(plugin.shown, isEmpty);
    });
  });

  group('taps', () {
    test('runtime taps publish decoded payloads and ignore junk', () async {
      final taps = <Map<String, String>>[];
      final subscription = service.taps.listen(taps.add);
      addTearDown(subscription.cancel);
      await service.initialize();
      plugin.onResponse!(tapResponse('{"route":"/notifications","id":"7"}'));
      plugin.onResponse!(tapResponse('{bad json'));
      plugin.onResponse!(tapResponse(null));
      await Future<void>.delayed(Duration.zero);
      expect(taps, [
        {'route': '/notifications', 'id': '7'},
      ]);
    });

    test('a launch payload is returned once per process', () async {
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: tapResponse('{"route":"/notifications"}'),
      );
      expect(await service.getInitialTapPayload(), {'route': '/notifications'});
      expect(await service.getInitialTapPayload(), isNull);
    });

    test('no launch, malformed or failed launch details give no tap', () async {
      plugin.launchDetails = const NotificationAppLaunchDetails(false);
      expect(await service.getInitialTapPayload(), isNull);

      final malformed = LocalNotificationService(plugin: plugin, log: logs.add);
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: tapResponse('[1]'),
      );
      expect(await malformed.getInitialTapPayload(), isNull);
    });
  });
}
