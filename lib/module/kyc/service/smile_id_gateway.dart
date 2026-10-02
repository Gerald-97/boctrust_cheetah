import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smile_id/products/models/model.dart';
import 'package:smile_id/products/biometric/smile_id_biometric_kyc.dart';
import 'package:smile_id/products/enhanceddocv/smile_id_enhanced_document_verification.dart';
import 'package:smile_id/smile_id.dart';

import '../model/kyc_models.dart';
import '../model/kyc_provider_models.dart';
import 'smile_id_initializer.dart';

enum SmileIdFlowOutcome { submitted, cancelled, failed }

class SmileIdConfigurationException implements Exception {
  const SmileIdConfigurationException(this.message);
  final String message;
}

/// Consent the user granted before capture, as Smile ID records it.
///
/// Captured in BocTrust UI rather than the SDK's own screen so the grant and
/// its timestamp can also be reported to the backend.
class KycCaptureConsent {
  const KycCaptureConsent({
    required this.grantedAtUtc,
    this.personalDetails = true,
    this.contactInformation = true,
    this.documentInformation = true,
  });

  final DateTime grantedAtUtc;
  final bool personalDetails;
  final bool contactInformation;
  final bool documentInformation;

  /// Smile expects an ISO 8601 instant.
  String get grantedDate => grantedAtUtc.toUtc().toIso8601String();
}

/// Values validated out of a backend initiation, shared by every Smile job.
class _SmileJobContext {
  const _SmileJobContext({
    required this.verificationId,
    required this.userId,
    required this.jobId,
    required this.callbackUrl,
    required this.extraPartnerParams,
  });

  /// Validates everything that is identical across products.
  ///
  /// [expectedJobType] is Smile's numeric job type, accepted as either an int
  /// or its string form because the backend has sent both.
  factory _SmileJobContext.from(
    KycInitiationData initiation, {
    required bool useSandbox,
    required int expectedJobType,
  }) {
    final expectedEnvironment = useSandbox ? 'sandbox' : 'live';
    if (initiation.environment != expectedEnvironment) {
      throw const SmileIdConfigurationException(
        'The backend and mobile Smile ID environments do not match.',
      );
    }

    final userId = _requireText(initiation.smileUserId, 'smileUserId');
    final jobId = _requireText(initiation.smileJobId, 'smileJobId');
    final callbackUrl = Uri.tryParse(
      _requireText(initiation.callbackUrl, 'callbackUrl'),
    );
    if (callbackUrl == null ||
        callbackUrl.scheme != 'https' ||
        callbackUrl.host.isEmpty) {
      throw const SmileIdConfigurationException(
        'The Smile ID callback URL must use HTTPS.',
      );
    }

    final extra = <String, String>{};
    for (final entry in initiation.partnerParams.entries) {
      switch (entry.key) {
        case 'user_id':
          if (entry.value is! String || entry.value != userId) {
            throw const SmileIdConfigurationException(
              'Conflicting Smile ID user IDs.',
            );
          }
        case 'job_id':
          if (entry.value is! String || entry.value != jobId) {
            throw const SmileIdConfigurationException(
              'Conflicting Smile ID job IDs.',
            );
          }
        case 'job_type':
          if (entry.value != expectedJobType &&
              entry.value != '$expectedJobType') {
            throw SmileIdConfigurationException(
              'The backend did not create Smile job type $expectedJobType.',
            );
          }
        default:
          if (entry.value is! String) {
            throw SmileIdConfigurationException(
              'Partner parameter ${entry.key} must be a string.',
            );
          }
          extra[entry.key] = entry.value! as String;
      }
    }

    return _SmileJobContext(
      verificationId: _requireText(initiation.verificationId, 'verificationId'),
      userId: userId,
      jobId: jobId,
      callbackUrl: callbackUrl,
      extraPartnerParams: Map.unmodifiable(extra),
    );
  }

  final String verificationId;
  final String userId;
  final String jobId;
  final Uri callbackUrl;
  final Map<String, String> extraPartnerParams;
}

String _requireText(String? value, String field) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    throw SmileIdConfigurationException('Missing $field.');
  }
  return text;
}

/// A capture job the gateway can launch.
///
/// Sealed so the host screen dispatches exhaustively and a new product cannot
/// be added without handling it.
sealed class SmileIdCaptureJob {
  const SmileIdCaptureJob();

  String get verificationId;
  Uri get callbackUrl;
}

/// Tier 1 identity: an ID-authority lookup plus selfie and liveness capture.
///
/// This is Smile job type 1. Enhanced KYC (job 5) cannot serve Tier 1 because
/// it captures no image at all.
final class SmileIdBiometricJob extends SmileIdCaptureJob {
  const SmileIdBiometricJob({
    required this.verificationId,
    required this.country,
    required this.idType,
    required this.idNumber,
    required this.userId,
    required this.jobId,
    required this.callbackUrl,
    required this.consent,
    required this.extraPartnerParams,
  });

  factory SmileIdBiometricJob.fromInitiation(
    KycInitiationData initiation, {
    required bool useSandbox,
    required IdentityType identityType,
    required String identityNumber,
    required KycCaptureConsent consent,
  }) {
    if (initiation.product != 'biometric_kyc' ||
        initiation.sdkJobType != 'biometricKyc') {
      throw const SmileIdConfigurationException(
        'The backend did not create a Biometric KYC job.',
      );
    }

    final context = _SmileJobContext.from(
      initiation,
      useSandbox: useSandbox,
      expectedJobType: 1,
    );

    // The backend may echo the country; Nigeria is the only market today.
    final country = initiation.country?.trim().isNotEmpty ?? false
        ? initiation.country!.trim()
        : kDefaultDocumentCountry;
    if (country != kDefaultDocumentCountry) {
      throw const SmileIdConfigurationException('Unsupported country.');
    }

    return SmileIdBiometricJob(
      verificationId: context.verificationId,
      country: country,
      idType: identityType.smileIdWireValue,
      idNumber: _requireText(identityNumber, 'identityNumber'),
      userId: context.userId,
      jobId: context.jobId,
      callbackUrl: context.callbackUrl,
      consent: consent,
      extraPartnerParams: context.extraPartnerParams,
    );
  }

  @override
  final String verificationId;
  final String country;
  final String idType;

  /// The full BVN or NIN. Held only until the SDK is handed it, then cleared.
  final String idNumber;
  final String userId;
  final String jobId;
  @override
  final Uri callbackUrl;
  final KycCaptureConsent consent;
  final Map<String, String> extraPartnerParams;
}

final class SmileIdDocumentJob extends SmileIdCaptureJob {
  const SmileIdDocumentJob({
    required this.verificationId,
    required this.country,
    required this.documentType,
    required this.captureBothSides,
    required this.userId,
    required this.jobId,
    required this.callbackUrl,
    required this.extraPartnerParams,
  });

  factory SmileIdDocumentJob.fromInitiation(
    KycInitiationData initiation, {
    required bool useSandbox,
  }) {
    if (initiation.product != 'enhanced_document_verification' ||
        initiation.sdkJobType != 'enhancedDocumentVerification') {
      throw const SmileIdConfigurationException(
        'The backend did not create an Enhanced Document Verification job.',
      );
    }

    final context = _SmileJobContext.from(
      initiation,
      useSandbox: useSandbox,
      expectedJobType: 11,
    );

    final selectedType = GovernmentIdDocumentType.tryParse(
      initiation.documentType,
    );
    final spec = selectedType?.smileIdDocumentSpec;
    if (selectedType == null ||
        !selectedType.isEnabledFor(KycProvider.smileId) ||
        spec == null) {
      throw const SmileIdConfigurationException('Unsupported document type.');
    }

    final country = _requireText(initiation.country, 'country');
    if (country != kDefaultDocumentCountry) {
      throw const SmileIdConfigurationException('Unsupported country.');
    }

    return SmileIdDocumentJob(
      verificationId: context.verificationId,
      country: country,
      documentType: spec.wireValue,
      captureBothSides: spec.captureBothSides,
      userId: context.userId,
      jobId: context.jobId,
      callbackUrl: context.callbackUrl,
      extraPartnerParams: context.extraPartnerParams,
    );
  }

  @override
  final String verificationId;
  final String country;
  final String documentType;
  final bool captureBothSides;
  final String userId;
  final String jobId;
  @override
  final Uri callbackUrl;
  final Map<String, String> extraPartnerParams;
}

/// Boundary over the Smile ID SDK.
///
/// [applyCallbackUrl] is separate from [buildEnhancedDocumentVerification]
/// because setting the callback URL mutates global SDK state; doing it from a
/// build path would re-fire on every rebuild of the host widget.
abstract interface class SmileIdGateway {
  Future<void> ensureInitialized();
  void resetInitialization();
  void applyCallbackUrl(Uri callbackUrl);

  /// Tier 1 identity capture: ID lookup plus selfie and liveness.
  Widget buildBiometricKyc({
    required SmileIdBiometricJob job,
    required ValueChanged<String> onSuccess,
    required ValueChanged<String> onError,
  });

  Widget buildEnhancedDocumentVerification({
    required SmileIdDocumentJob job,
    required ValueChanged<String> onSuccess,
    required ValueChanged<String> onError,
  });
}

final smileIdGatewayProvider = Provider<SmileIdGateway>(
  (ref) =>
      SmileIdV11Gateway(initializer: ref.watch(smileIdInitializerProvider)),
);

/// Production gateway over the Smile ID v11 Flutter SDK.
///
/// Everything Smile-specific lives behind [SmileIdGateway] so the v12
/// migration replaces one file rather than every call site.
class SmileIdV11Gateway implements SmileIdGateway {
  SmileIdV11Gateway({required this.initializer});

  final SmileIdInitializer initializer;

  @override
  Future<void> ensureInitialized() => initializer.ensureInitialized();

  @override
  void resetInitialization() => initializer.resetInitialization();

  @override
  void applyCallbackUrl(Uri callbackUrl) =>
      SmileID.setCallbackUrl(callbackUrl: callbackUrl);

  @override
  Widget buildBiometricKyc({
    required SmileIdBiometricJob job,
    required ValueChanged<String> onSuccess,
    required ValueChanged<String> onError,
  }) {
    return SmileIDBiometricKYC(
      country: job.country,
      idType: job.idType,
      idNumber: job.idNumber,
      // The user typed the number, so Smile skips its own entry screen and
      // goes straight to selfie and liveness capture.
      entered: true,
      userId: job.userId,
      jobId: job.jobId,
      consentGrantedDate: job.consent.grantedDate,
      personalDetailsConsentGranted: job.consent.personalDetails,
      contactInformationConsentGranted: job.consent.contactInformation,
      documentInformationConsentGranted: job.consent.documentInformation,
      showInstructions: true,
      skipApiSubmission: false,
      // Enhanced SmartSelfie capture, which is the stronger liveness check.
      useStrictMode: true,
      extraPartnerParams: job.extraPartnerParams,
      onSuccess: onSuccess,
      onError: onError,
    );
  }

  @override
  Widget buildEnhancedDocumentVerification({
    required SmileIdDocumentJob job,
    required ValueChanged<String> onSuccess,
    required ValueChanged<String> onError,
  }) {
    return SmileIDEnhancedDocumentVerification(
      countryCode: job.country,
      documentType: job.documentType,
      captureBothSides: job.captureBothSides,
      userId: job.userId,
      jobId: job.jobId,
      autoCapture: AutoCaptureMode.autoCapture,
      autoCaptureTimeout: 10000,
      allowGalleryUpload: false,
      showInstructions: true,
      skipApiSubmission: false,
      useStrictMode: true,
      extraPartnerParams: job.extraPartnerParams,
      onSuccess: onSuccess,
      onError: onError,
    );
  }
}
