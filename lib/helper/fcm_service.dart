import 'package:firebase_messaging/firebase_messaging.dart';
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

  Future<String?> getToken() => _messaging.getToken();
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();
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
