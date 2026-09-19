import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/kyc_provider_models.dart';

class DojahConfig {
  const DojahConfig({
    required this.selfieWidgetId,
    required this.governmentWidgetId,
  });

  final String selfieWidgetId;
  final String governmentWidgetId;

  String widgetIdFor(KycOperation operation) => switch (operation) {
    KycOperation.identity => selfieWidgetId.trim(),
    KycOperation.governmentId => governmentWidgetId.trim(),
  };

  bool isConfigured(KycOperation operation) =>
      widgetIdFor(operation).isNotEmpty;
}

/// The BVN Dojah's sandbox verifies. Other numbers fail sandbox lookup, so
/// sandbox attempts send this one instead of the BVN the user entered.
const dojahSandboxBvn = '22222222222';

/// The BVN to prefill into Dojah for an attempt in [environment].
String dojahCaptureBvn(String enteredBvn, {required String? environment}) =>
    environment == 'sandbox' ? dojahSandboxBvn : enteredBvn;

final dojahConfigProvider = Provider<DojahConfig>(
  (ref) => const DojahConfig(
    selfieWidgetId: Env.dojahSelfieWidgetId,
    governmentWidgetId: Env.dojahGovernmentWidgetId,
  ),
);
