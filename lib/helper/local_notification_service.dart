import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app/api_logger.dart';
import 'notification_payload.dart';

/// The single boundary that displays remote messages as local notifications
/// and reports local-notification taps.
class LocalNotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    void Function(String message)? log,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _log = log ?? apiLogger.w;

  /// Android small icon. Stays the launcher icon until the designer-approved
  /// monochrome `ic_stat_boctrust` drawable exists; a missing drawable would
  /// make initialization fail.
  static const androidSmallIcon = '@mipmap/ic_launcher';
  static const channelId = 'boctrust_general';
  static const channelName = 'BOCTRUST notifications';

  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String message) _log;
  final _taps = StreamController<Map<String, String>>.broadcast();
  Future<bool>? _initialized;
  bool _launchConsumed = false;

  /// Normalized `route`/`id` payloads of notifications tapped while the app
  /// is running.
  Stream<Map<String, String>> get taps => _taps.stream;

  /// Initializes the plugin and channel once. Returns false, without
  /// throwing, when the platform is unavailable; a later call retries.
  Future<bool> initialize() => _initialized ??= _initialize().then((ready) {
    if (!ready) _initialized = null;
    return ready;
  });

  Future<bool> _initialize() async {
    try {
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings(androidSmallIcon),
          iOS: darwin,
          macOS: darwin,
        ),
        onDidReceiveNotificationResponse: _onResponse,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              channelId,
              channelName,
              importance: Importance.high,
            ),
          );
      return true;
    } catch (error) {
      _log('Local notifications unavailable: ${error.runtimeType}');
      return false;
    }
  }

  void _onResponse(NotificationResponse response) {
    final payload = NotificationPayload.decodeLocalPayload(response.payload);
    if (payload != null) _taps.add(payload);
  }

  /// Shows [message] with generic copy. Messages with nothing to display are
  /// skipped; failures are logged without message content and never thrown.
  Future<void> showRemoteMessage(RemoteMessage message) async {
    final payload = NotificationPayload.fromRemoteMessage(message);
    if (!payload.isDisplayable || !await initialize()) return;
    try {
      await _plugin.show(
        payload.notificationId,
        NotificationPayload.title,
        NotificationPayload.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
            icon: androidSmallIcon,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: true,
          ),
        ),
        payload: payload.toLocalPayload(),
      );
    } catch (error) {
      _log(
        'Local notification ${payload.notificationId} not shown: '
        '${error.runtimeType}',
      );
    }
  }

  /// The payload of the notification that launched the app, returned at most
  /// once per process: the plugin keeps reporting the same launch, which
  /// would otherwise replay on rebuilds.
  Future<Map<String, String>?> getInitialTapPayload() async {
    if (_launchConsumed) return null;
    _launchConsumed = true;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return NotificationPayload.decodeLocalPayload(
        details.notificationResponse?.payload,
      );
    } catch (error) {
      _log('Notification launch details unavailable: ${error.runtimeType}');
      return null;
    }
  }
}
