import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  FCMService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  Future<String?> initialize() async {
    await _messaging.requestPermission();
    return _messaging.getToken();
  }
}
