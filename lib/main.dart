import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app/services.dart';
import 'helper/fcm_service.dart';
import 'helper/local_notification_service.dart';
import 'helper/notification_delivery.dart';
import 'helper/notification_navigator.dart';

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

  final notifications = LocalNotificationService();
  notifications.taps.listen(
    (payload) => unawaited(NotificationNavigator.dispatch(payload)),
  );
  await notifications.initialize();
  if (firebaseReady) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    displayForegroundMessages(FCMService().onMessage, notifications);
  }
  final preferences = await SharedPreferences.getInstance();
  runApp(CheetahApp(preferences: preferences, firebaseReady: firebaseReady));
}
