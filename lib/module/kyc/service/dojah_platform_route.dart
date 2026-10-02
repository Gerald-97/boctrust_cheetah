import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';

/// How this device presents Dojah capture.
///
/// iOS never had the native plugin: it is registered for Android only, so
/// iOS uses the hosted flow in an embedded browser for every operation.
///
/// Android runs BVN liveness in the native SDK, whose camera-based liveness
/// does not depend on the embedded browser's face model, and keeps the
/// government-ID flow in the browser. `sdk-kotlin` v0.4.2 advances a
/// persisted page index on every destination change without bounding it
/// against the page list, so navigating back on the document pages makes
/// `getCurrentPageName` return null and `GovDataViewModel.logIdOptionEvents`
/// throw `No stepNumber` from its own coroutine, killing the host process.
/// The BVN and selfie flow has no document pages, so only the document flow
/// stays out of the SDK.
enum DojahPlatformRoute {
  /// The hosted flow in an embedded browser for every operation.
  webView,

  /// The native SDK for identity, the embedded browser for documents.
  androidNativeIdentity,

  unsupported,
}

/// How one capture is presented.
enum DojahCaptureMode { nativeSdk, webView, unsupported }

DojahPlatformRoute chooseDojahPlatformRoute({
  required bool isWeb,
  required bool isAndroid,
  required bool isIOS,
}) {
  if (isWeb) return DojahPlatformRoute.unsupported;
  if (isAndroid) return DojahPlatformRoute.androidNativeIdentity;
  if (isIOS) return DojahPlatformRoute.webView;
  return DojahPlatformRoute.unsupported;
}

DojahCaptureMode dojahCaptureMode(
  DojahPlatformRoute route,
  KycOperation operation,
) => switch (route) {
  DojahPlatformRoute.webView => DojahCaptureMode.webView,
  DojahPlatformRoute.androidNativeIdentity =>
    operation == KycOperation.identity
        ? DojahCaptureMode.nativeSdk
        : DojahCaptureMode.webView,
  DojahPlatformRoute.unsupported => DojahCaptureMode.unsupported,
};

final dojahPlatformRouteProvider = Provider<DojahPlatformRoute>(
  (ref) => chooseDojahPlatformRoute(
    isWeb: kIsWeb,
    isAndroid: defaultTargetPlatform == TargetPlatform.android,
    isIOS: defaultTargetPlatform == TargetPlatform.iOS,
  ),
);
