import 'package:dojah_kyc_sdk_flutter/dojah_kyc_sdk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/kyc_provider_models.dart';

typedef DojahNativeLaunch =
    Future<String?> Function(String widgetId, {required String referenceId});

abstract interface class DojahGateway {
  Future<KycCaptureOutcome> launch({
    required String widgetId,
    required String referenceId,
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
  }) async {
    if (widgetId.trim().isEmpty || referenceId.trim().isEmpty) {
      throw const FormatException('Invalid capture configuration.');
    }
    if (_launching) throw StateError('Dojah capture is already open.');

    _launching = true;
    try {
      final result = await _launch(
        widgetId.trim(),
        referenceId: referenceId.trim(),
      );
      return result?.trim().toLowerCase() == 'closed'
          ? KycCaptureOutcome.cancelled
          : KycCaptureOutcome.unknown;
    } finally {
      _launching = false;
    }
  }
}

final dojahGatewayProvider = Provider<DojahGateway>(
  (ref) => NativeDojahGateway(
    (widgetId, {required referenceId}) =>
        DojahKyc.launch(widgetId, referenceId: referenceId),
  ),
);
