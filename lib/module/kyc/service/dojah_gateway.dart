import 'package:dojah_kyc_sdk_flutter/dojah_extra_flutter_data.dart';
import 'package:dojah_kyc_sdk_flutter/dojah_kyc_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';

typedef DojahNativeLaunch =
    Future<String?> Function(
      String widgetId, {
      required Map<String, Object?> metadata,
      String? bvn,
    });

abstract interface class DojahGateway {
  /// [bvn] prefills the number the user already entered, so Dojah does not
  /// ask for it again.
  Future<KycCaptureOutcome> launch({
    required String widgetId,
    required String referenceId,
    String? bvn,
  });
}

class NativeDojahGateway implements DojahGateway {
  NativeDojahGateway(this._launch);

  final DojahNativeLaunch _launch;
  bool _launching = false;

  @override
  Future<KycCaptureOutcome> launch({
    required String widgetId,
    required String referenceId,
    String? bvn,
  }) async {
    if (widgetId.trim().isEmpty || referenceId.trim().isEmpty) {
      throw const FormatException('Invalid capture configuration.');
    }
    if (_launching) throw StateError('Dojah capture is already open.');

    _launching = true;
    try {
      final result = await _launch(
        widgetId.trim(),
        metadata: dojahAttemptMetadata(referenceId),
        bvn: dojahBvnPrefill(bvn),
      );
      return dojahNativeOutcome(result);
    } finally {
      _launching = false;
    }
  }
}

/// How a Dojah session carries the backend attempt on both platforms.
///
/// Dojah documents its top-level `referenceId` as initializing the SDK for an
/// ongoing verification, so it resumes an existing Dojah session. The backend
/// reference is not one, so it travels as custom metadata instead, which the
/// hosted flow sends as `metadata[reference]`.
Map<String, Object?> dojahAttemptMetadata(String referenceId) => {
  'reference': referenceId.trim(),
};

/// The known email address to prefill, or null when there is none to send.
String? dojahEmailPrefill(String? email) {
  final value = email?.trim() ?? '';
  return value.isEmpty ? null : value;
}

/// The entered BVN to prefill, or null when there is none to send.
String? dojahBvnPrefill(String? bvn) {
  final value = bvn?.trim() ?? '';
  return value.isEmpty ? null : value;
}

/// Classifies the Android SDK's result string.
///
/// Only the `DOJAH_*_RESULT` constants in `com.dojah.kyc_sdk_kotlin.DojahSdkKt`
/// (SDK 0.4.2) mean anything. The plugin substitutes 'Verification Completed'
/// for a null result and may report native exceptions as successful replies,
/// so any other string is [KycCaptureOutcome.unknown]. Every outcome is a
/// capture outcome; the backend still decides verification.
KycCaptureOutcome dojahNativeOutcome(String? result) =>
    switch (result?.trim().toLowerCase()) {
      'approved' || 'pending' => KycCaptureOutcome.submitted,
      'failed' => KycCaptureOutcome.failed,
      'closed' => KycCaptureOutcome.cancelled,
      _ => KycCaptureOutcome.unknown,
    };

final dojahGatewayProvider = Provider<DojahGateway>(
  (ref) => NativeDojahGateway(
    (widgetId, {required metadata, bvn}) => DojahKyc.launch(
      widgetId,
      // SDK 0.4.2's ExtraUserData has no country field, so Android cannot
      // preset Nigeria here; the widget's dashboard configuration must.
      extraUserData: ExtraUserData(
        govData: bvn == null ? null : GovData(bvn: bvn),
        metadata: metadata,
      ),
    ),
  ),
);
