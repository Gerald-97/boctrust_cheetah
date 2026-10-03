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

/// Which government documents each provider accepts for Tier 2.
///
/// The provider is chosen by the backend per attempt, so a document is only
/// launchable once the provider that answers the initiation accepts it.
extension GovernmentIdDocumentTypeCapability on GovernmentIdDocumentType {
  /// Whether [provider] can verify this document type.
  ///
  /// This is a local SDK-compatibility gate layered under the server's
  /// document catalogue, never a replacement for it.
  ///
  /// Dojah accepts every type the app offers: its widget, not the launch
  /// call, decides which documents it presents, so the set here must match
  /// the documents enabled on `DOJAH_GOVERNMENT_WIDGET_ID` in the Dojah
  /// dashboard. `national_id` was confirmed there on 2 October 2026. Smile's published Enhanced Document Verification matrix lists
  /// only Nigerian `VOTER_ID`; each other type stays disabled there until a
  /// sandbox submission succeeds for this partner on both platforms and its
  /// document webhook reaches pending or success. Never substitute job 6 or
  /// Biometric KYC to work around a disabled type; that needs a backend
  /// contract change.
  bool isEnabledFor(KycProvider provider) => switch (provider) {
    KycProvider.dojah => true,
    KycProvider.smileId => this == GovernmentIdDocumentType.voterId,
  };
}

/// Why [provider] cannot verify [type], or null when it can.
///
/// The provider is only known once initiation answers, so the document the
/// user chose can turn out to be one this provider cannot verify. The user
/// can pick another on the form, so the message names a document that works
/// rather than sending them to support. Alternatives come only from
/// [offeredTypes], the documents the live catalogue currently offers, so the
/// copy never suggests one the server has turned off. A null [type] is not a
/// problem: the backend need not echo a document for the attempt to be
/// launchable.
String? governmentIdUnsupportedMessage(
  GovernmentIdDocumentType? type,
  KycProvider provider, {
  required Iterable<GovernmentIdDocumentType> offeredTypes,
}) {
  if (type == null || type.isEnabledFor(provider)) return null;
  final alternatives = offeredTypes
      .where((candidate) => candidate.isEnabledFor(provider))
      .map((candidate) => candidate.label)
      .toSet()
      .toList(growable: false);
  if (alternatives.isEmpty) {
    return '${type.label} cannot be verified right now. Please contact '
        'support.';
  }
  return '${type.label} is not supported by the verification method '
      'available right now. Choose ${alternatives.join(' or ')} instead.';
}

enum KycCaptureOutcome { submitted, cancelled, failed, unknown }

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
  if (provider == KycProvider.dojah && data.contractVersion == null) {
    // Pre-v2 Dojah initiation: no attempt ID or launch expiry to check, so
    // the backend must reject a stale result when its webhook arrives.
    final operationValue = data.operation;
    if (operationValue != null &&
        KycOperation.tryParse(operationValue) != operation) {
      throw const FormatException('The verification operation does not match.');
    }
    if ((data.country ?? kDefaultDocumentCountry) != kDefaultDocumentCountry) {
      throw const FormatException('Unsupported country.');
    }
    if (data.referenceId?.trim().isEmpty != false) {
      throw const FormatException('Missing Dojah reference.');
    }
    return provider;
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
