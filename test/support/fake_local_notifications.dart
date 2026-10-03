import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Records what [FakeLocalNotificationsPlugin.show] was asked to display.
class ShownNotification {
  ShownNotification(this.id, this.title, this.body, this.details, this.payload);
  final int id;
  final String? title;
  final String? body;
  final NotificationDetails? details;
  final String? payload;
}

class FakeAndroidNotifications
    implements AndroidFlutterLocalNotificationsPlugin {
  final channels = <AndroidNotificationChannel>[];

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async => channels.add(notificationChannel);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLocalNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  final android = FakeAndroidNotifications();
  final initializations = <InitializationSettings>[];
  final shown = <ShownNotification>[];
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
    shown.add(ShownNotification(id, title, body, notificationDetails, payload));
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

NotificationResponse tapResponse(String? payload) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotification,
  payload: payload,
);
