import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Initializes Firebase with the FlutterFire-generated options. Used by the
/// app and the background message handler alike.
Future<FirebaseApp> initializeFirebase() =>
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
