import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'local_notification_service.dart';
import 'notification_payload.dart';

/// Whether a background message needs a local notification. Messages with a
/// `notification` block are displayed by the OS and must not be duplicated.
bool shouldDisplayInBackground(RemoteMessage message) =>
    message.notification == null &&
    NotificationPayload.fromRemoteMessage(message).isDisplayable;

/// Firebase background entry point. Runs in its own isolate: it must not
/// touch Riverpod, secure storage, API clients or navigation.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    handleBackgroundMessage(
      message,
      initializeFirebase: Firebase.initializeApp,
      notifications: LocalNotificationService.new,
    );

Future<void> handleBackgroundMessage(
  RemoteMessage message, {
  required Future<Object?> Function() initializeFirebase,
  required LocalNotificationService Function() notifications,
}) async {
  if (!shouldDisplayInBackground(message)) return;
  try {
    await initializeFirebase();
  } catch (_) {
    // Local display does not depend on Firebase being initialized here.
  }
  try {
    await notifications().showRemoteMessage(message);
  } catch (_) {
    // A background message must never crash the handler isolate.
  }
}

/// Shows each foreground message as one local notification.
StreamSubscription<RemoteMessage> displayForegroundMessages(
  Stream<RemoteMessage> messages,
  LocalNotificationService notifications,
) => messages.listen(notifications.showRemoteMessage);
