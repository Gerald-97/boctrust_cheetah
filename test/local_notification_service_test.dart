import 'dart:convert';

import 'package:boctrust_savings_loan/helper/local_notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

class _Shown {
  _Shown(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String? title;
  final String? body;
  final NotificationDetails? details;
  final String? payload;
}

class _FakeAndroid implements AndroidFlutterLocalNotificationsPlugin {
  final channels = <AndroidNotificationChannel>[];

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async => channels.add(notificationChannel);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final android = _FakeAndroid();
  final initializations = <InitializationSettings>[];
  final shown = <_Shown>[];
  DidReceiveNotificationResponseCallback? onResponse;
  NotificationAppLaunchDetails? launchDetails;
  Object? initializeError;
  Object? showError;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    if (initializeError case final error?) throw error;
    initializations.add(initializationSettings);
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => android is T ? android as T : null;

  @override
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    if (showError case final error?) throw error;
    shown.add(_Shown(id, title, body, notificationDetails, payload));
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationResponse _response(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);

const _secretMessage = RemoteMessage(
  messageId: 'msg-1',
  data: {'route': '/notifications', 'id': 'n-1', 'balance': '₦99,000'},
  notification: RemoteNotification(
    title: 'Ada, your balance is ₦99,000',
    body: 'Account 0123456789 credited',
  ),
);

void main() {
  late _FakePlugin plugin;
  late List<String> logs;
  late LocalNotificationService service;

  setUp(() {
    plugin = _FakePlugin();
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
      plugin.onResponse!(_response('{"route":"/notifications","id":"7"}'));
      plugin.onResponse!(_response('{bad json'));
      plugin.onResponse!(_response(null));
      await Future<void>.delayed(Duration.zero);
      expect(taps, [
        {'route': '/notifications', 'id': '7'},
      ]);
    });

    test('a launch payload is returned once per process', () async {
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: _response('{"route":"/notifications"}'),
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
        notificationResponse: _response('[1]'),
      );
      expect(await malformed.getInitialTapPayload(), isNull);
    });
  });
}
