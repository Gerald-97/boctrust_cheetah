import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How this device presents Dojah capture. iOS never uses the native plugin:
/// it is registered for Android only, and iOS uses an embedded browser.
enum DojahPlatformRoute { nativeAndroid, iosWebView, unsupported }

DojahPlatformRoute chooseDojahPlatformRoute({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
}) {
  if (isWeb) return DojahPlatformRoute.unsupported;
  if (isIOS) return DojahPlatformRoute.iosWebView;
  if (isAndroid) return DojahPlatformRoute.nativeAndroid;
  return DojahPlatformRoute.unsupported;
}

final dojahPlatformRouteProvider = Provider<DojahPlatformRoute>(
  (ref) => chooseDojahPlatformRoute(
    isWeb: kIsWeb,
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
    isIOS: defaultTargetPlatform == TargetPlatform.iOS,
  ),
);
