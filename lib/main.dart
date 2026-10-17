import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app/services.dart';
import 'helper/fcm_service.dart';
import 'helper/firebase_bootstrap.dart';
import 'helper/local_notification_service.dart';
import 'helper/notification_delivery.dart';
import 'module/app_flow/app_ui.dart' show BocBrandMark;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBootstrap.initialize();
  // Cached while the native splash shows, so Flutter's first splash frame
  // already has the mark.
  final brandMarkReady = BocBrandMark.precache();

  var firebaseReady = false;
  try {
    await initializeFirebase();
    firebaseReady = true;
  } catch (_) {
    firebaseReady = false;
  }

  // Taps are routed by AuthFlowListener once authentication is ready; a
  // failed initialization leaves an inert service and never blocks startup.
  final notifications = LocalNotificationService();
  appNotificationService = notifications;
  await notifications.initialize();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    displayForegroundMessages(FCMService().onMessage, notifications);
  }
  final preferences = await SharedPreferences.getInstance();
  await brandMarkReady;
  runApp(
    CheetahApp(
      preferences: preferences,
      firebaseReady: firebaseReady,
      notifications: notifications,
    ),
  );
}
