import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Asks for whatever the embedded browser needs before it can use the camera.
/// Returns whether capture may proceed.
typedef DojahCameraPermissionRequest = Future<bool> Function();

/// Whether the app itself must hold the camera permission on this platform.
///
/// Android's WebView can only satisfy a page's `getUserMedia` while the host
/// app holds runtime `CAMERA`; granting the web permission request alone is
/// not enough. WKWebView prompts on its own behalf using the `Info.plist`
/// usage descriptions, so iOS needs nothing here.
bool dojahNeedsCameraPermission({required bool isAndroid}) => isAndroid;

/// Requests runtime camera access where the platform requires it.
///
/// A permanently denied permission is reported as refused rather than
/// re-requested: the system will not prompt again, so only the app settings
/// can change it.
Future<bool> requestDojahCameraPermission({required bool isAndroid}) async {
  if (!dojahNeedsCameraPermission(isAndroid: isAndroid)) return true;
  final status = await Permission.camera.request();
  return status.isGranted || status.isLimited;
}

final dojahCameraPermissionProvider = Provider<DojahCameraPermissionRequest>(
  (ref) =>
      () => requestDojahCameraPermission(
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
      ),
);
