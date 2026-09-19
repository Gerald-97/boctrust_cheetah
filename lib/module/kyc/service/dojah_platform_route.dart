import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How this device presents Dojah capture.
///
/// Both phone platforms use the hosted flow in an embedded browser. iOS never
/// had the native plugin: it is registered for Android only. Android left it
/// because `sdk-kotlin` v0.4.2 advances a persisted page index on every
/// destination change without bounding it against the page list, so
/// navigating back on the document pages makes `getCurrentPageName` return
/// null and `GovDataViewModel.logIdOptionEvents` throw `No stepNumber` from
/// its own coroutine, killing the host process. v0.4.2 is the newest release
/// of both the plugin and the Kotlin SDK, so there is nothing to upgrade to.
/// A page in a browser cannot take the app down with it.
enum DojahPlatformRoute { webView, unsupported }

DojahPlatformRoute chooseDojahPlatformRoute({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
}) {
  if (isWeb) return DojahPlatformRoute.unsupported;
  if (isIOS || isAndroid) return DojahPlatformRoute.webView;
  return DojahPlatformRoute.unsupported;
}

final dojahPlatformRouteProvider = Provider<DojahPlatformRoute>(
  (ref) => chooseDojahPlatformRoute(
    isWeb: kIsWeb,
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
    isIOS: defaultTargetPlatform == TargetPlatform.iOS,
  ),
);
