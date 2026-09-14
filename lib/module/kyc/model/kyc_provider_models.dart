import 'kyc_models.dart';

enum KycProvider {
  dojah('dojah', 'Dojah'),
  smileId('smile_id', 'Smile ID');

  const KycProvider(this.wireValue, this.label);
  final String wireValue;
  final String label;

  static KycProvider? tryParse(Object? value) {
    for (final provider in values) {
      if (provider.wireValue == value) return provider;
    }
    return null;
  }
}

enum KycOperation {
  identity('identity'),
  governmentId('government_id');

  const KycOperation(this.wireValue);
  final String wireValue;

  static KycOperation? tryParse(Object? value) {
    for (final operation in values) {
      if (operation.wireValue == value) return operation;
    }
    return null;
  }
}

enum KycCaptureOutcome { submitted, cancelled, failed, unknown }

KycFlowStage stageAfterCapture(KycCaptureOutcome outcome) => switch (outcome) {
  KycCaptureOutcome.submitted => KycFlowStage.pendingReview,
  KycCaptureOutcome.cancelled => KycFlowStage.awaitingProvider,
  KycCaptureOutcome.failed => KycFlowStage.failed,
  KycCaptureOutcome.unknown => KycFlowStage.reconciling,
};

KycProvider validateKycLaunch(
  KycInitiationData data, {
  required KycOperation operation,
  required bool useSandbox,
  required DateTime now,
}) {
  final expectedEnvironment = useSandbox ? 'sandbox' : 'live';
  if (data.environment != expectedEnvironment) {
    throw const FormatException('The provider environment does not match.');
  }

  final explicitProvider = data.provider;
  final hasLegacySmileContext =
      (data.smileUserId?.trim().isNotEmpty ?? false) &&
      (data.smileJobId?.trim().isNotEmpty ?? false) &&
      (data.callbackUrl?.trim().isNotEmpty ?? false);
  if (data.contractVersion == null &&
      (explicitProvider == null ||
          explicitProvider == KycProvider.smileId.wireValue) &&
      hasLegacySmileContext) {
    return KycProvider.smileId;
  }

  final provider = KycProvider.tryParse(explicitProvider);
  if (provider == null) {
    throw const FormatException('Unsupported KYC provider.');
  }
  if (data.contractVersion != 2 || data.attemptId?.trim().isEmpty != false) {
    throw const FormatException('Invalid verification attempt.');
  }
  if (KycOperation.tryParse(data.operation) != operation) {
    throw const FormatException('The verification operation does not match.');
  }
  if ((data.country ?? kDefaultDocumentCountry) != kDefaultDocumentCountry) {
    throw const FormatException('Unsupported country.');
  }
  final expiry = data.launchExpiresAt;
  if (expiry == null || !expiry.isAfter(now.toUtc())) {
    throw const FormatException('The verification attempt has expired.');
  }
  if (provider == KycProvider.dojah &&
      data.referenceId?.trim().isEmpty != false) {
    throw const FormatException('Missing Dojah reference.');
  }
  return provider;
}

class KycConsentRecord {
  const KycConsentRecord({
    required this.provider,
    required this.version,
    required this.grantedAtUtc,
    this.personalDetails = true,
    this.contactInformation = true,
    this.documentInformation = true,
  });

  final KycProvider provider;
  final String version;
  final DateTime grantedAtUtc;
  final bool personalDetails;
  final bool contactInformation;
  final bool documentInformation;

  Map<String, Object?> toJson() => {
    'provider': provider.wireValue,
    'version': version,
    'grantedAt': grantedAtUtc.toUtc().toIso8601String(),
    'personalDetails': personalDetails,
    'contactInformation': contactInformation,
    'documentInformation': documentInformation,
  };
}
