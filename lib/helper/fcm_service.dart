import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseReadyProvider = Provider<bool>((ref) => false);

final fcmServiceProvider = Provider<FCMService>((ref) => FCMService());

class FCMService {
  FCMService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission(alert: true, badge: true, sound: true);

  /// The FCM registration token. On iOS FCM cannot issue one until APNs has
  /// delivered the device token, which can lag app start; waiting briefly
  /// keeps the first sign-in from registering nothing.
  Future<String?> getToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var i = 0; i < _apnsAttempts; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(_apnsRetryDelay);
      }
    }
    return _messaging.getToken();
  }

  static const _apnsAttempts = 6;
  static const _apnsRetryDelay = Duration(milliseconds: 500);
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();
  Future<void> deleteToken() => _messaging.deleteToken();
}

final fcmTokenRefreshProvider = StreamProvider<String>(
  (ref) => ref.watch(firebaseReadyProvider)
      ? ref.watch(fcmServiceProvider).onTokenRefresh
      : const Stream<String>.empty(),
);

final fcmNotificationOpenedProvider = StreamProvider<RemoteMessage>(
  (ref) => ref.watch(firebaseReadyProvider)
      ? ref.watch(fcmServiceProvider).onMessageOpenedApp
      : const Stream<RemoteMessage>.empty(),
);
