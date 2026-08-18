import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app/services.dart';
import 'helper/local_notification_service.dart';
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

  await LocalNotificationService().initialize(
    onNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          unawaited(
            NotificationNavigator.dispatch(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {
        // Ignore malformed external notification payloads.
      }
    },
  );
  final preferences = await SharedPreferences.getInstance();
  runApp(BOCTrustApp(preferences: preferences, firebaseReady: firebaseReady));
}
