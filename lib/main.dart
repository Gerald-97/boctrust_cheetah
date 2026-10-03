import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app/services.dart';
import 'helper/fcm_service.dart';
import 'helper/local_notification_service.dart';
import 'helper/notification_delivery.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppBootstrap.initialize();

  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
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
  runApp(
    CheetahApp(
      preferences: preferences,
      firebaseReady: firebaseReady,
      notifications: notifications,
    ),
  );
}
