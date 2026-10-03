import 'dart:async';

import 'package:boctrust_savings_loan/helper/local_notification_service.dart';
import 'package:boctrust_savings_loan/helper/notification_delivery.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_local_notifications.dart';

const _dataOnly = RemoteMessage(
  messageId: 'data-1',
  data: {'route': '/notifications', 'id': 'n-1'},
);
const _withNotification = RemoteMessage(
  messageId: 'notif-1',
  data: {'route': '/notifications'},
  notification: RemoteNotification(title: 'Hi', body: 'There'),
);
const _empty = RemoteMessage(messageId: 'empty-1', data: {'x': 'y'});

void main() {
  late FakeLocalNotificationsPlugin plugin;
  late LocalNotificationService service;

  setUp(() {
    plugin = FakeLocalNotificationsPlugin();
    service = LocalNotificationService(plugin: plugin, log: (_) {});
  });

  group('shouldDisplayInBackground', () {
    test('data-only messages with a payload are displayed locally', () {
      expect(shouldDisplayInBackground(_dataOnly), isTrue);
    });

    test('notification-payload messages are left to the OS', () {
      expect(shouldDisplayInBackground(_withNotification), isFalse);
    });

    test('empty messages are not displayed', () {
      expect(shouldDisplayInBackground(_empty), isFalse);
    });
  });

  group('handleBackgroundMessage', () {
    Future<void> handle(
      RemoteMessage message, {
      Future<void> Function()? initializeFirebase,
    }) => handleBackgroundMessage(
      message,
      initializeFirebase: initializeFirebase ?? () async => null,
      notifications: () => service,
    );

    test('a data-only message is displayed once', () async {
      var firebaseInitialized = 0;
      await handle(
        _dataOnly,
        initializeFirebase: () async => firebaseInitialized++,
      );
      expect(plugin.shown, hasLength(1));
      expect(firebaseInitialized, 1);
    });

    test('a notification-payload message is not displayed locally', () async {
      var firebaseInitialized = 0;
      await handle(
        _withNotification,
        initializeFirebase: () async => firebaseInitialized++,
      );
      expect(plugin.shown, isEmpty);
      expect(firebaseInitialized, 0);
    });

    test('an empty message is ignored', () async {
      await handle(_empty);
      expect(plugin.shown, isEmpty);
    });

    test('a Firebase initialization failure does not throw', () async {
      await expectLater(
        handle(
          _dataOnly,
          initializeFirebase: () async => throw StateError('no firebase'),
        ),
        completes,
      );
      expect(plugin.shown, hasLength(1));
    });

    test('a display failure does not throw', () async {
      plugin.showError = Exception('display failed');
      await expectLater(handle(_dataOnly), completes);
    });

    test('an unavailable notification service does not throw', () async {
      await expectLater(
        handleBackgroundMessage(
          _dataOnly,
          initializeFirebase: () async => null,
          notifications: () => throw StateError('no plugin'),
        ),
        completes,
      );
    });
  });

  group('displayForegroundMessages', () {
    test('each usable foreground message is displayed exactly once', () async {
      final messages = StreamController<RemoteMessage>();
      final subscription = displayForegroundMessages(messages.stream, service);
      addTearDown(subscription.cancel);
      messages
        ..add(_dataOnly)
        ..add(_withNotification)
        ..add(_empty);
      await messages.close();
      await pumpEventQueue();
      expect(plugin.shown, hasLength(2));
      expect(plugin.shown.map((s) => s.title).toSet(), {'BOCTRUST'});
    });
  });
}
