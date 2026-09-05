import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smile_id/products/models/model.dart';
import 'package:smile_id/products/enhanceddocv/smile_id_enhanced_document_verification.dart';
import 'package:smile_id/smile_id.dart';

import '../model/kyc_models.dart';
import 'smile_id_initializer.dart';

enum SmileIdFlowOutcome { submitted, cancelled, failed }

class SmileIdConfigurationException implements Exception {
  const SmileIdConfigurationException(this.message);
  final String message;
}

class SmileIdDocumentJob {
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
    String requireText(String? value, String field) {
      final text = value?.trim() ?? '';
      if (text.isEmpty) {
        throw SmileIdConfigurationException('Missing $field.');
      }
      return text;
    }

    if (initiation.product != 'enhanced_document_verification' ||
        initiation.sdkJobType != 'enhancedDocumentVerification') {
      throw const SmileIdConfigurationException(
        'The backend did not create an Enhanced Document Verification job.',
      );
    }
    final expectedEnvironment = useSandbox ? 'sandbox' : 'live';
    if (initiation.environment != expectedEnvironment) {
      throw const SmileIdConfigurationException(
        'The backend and mobile Smile ID environments do not match.',
      );
    }

    GovernmentIdDocumentType? selectedType;
    for (final type in GovernmentIdDocumentType.values) {
      if (type.wireValue == initiation.documentType) selectedType = type;
    }
    if (selectedType == null) {
      throw const SmileIdConfigurationException('Unsupported document type.');
    }

    final country = requireText(initiation.country, 'country');
    if (country != kDefaultDocumentCountry) {
      throw const SmileIdConfigurationException('Unsupported country.');
    }
    final userId = requireText(initiation.smileUserId, 'smileUserId');
    final jobId = requireText(initiation.smileJobId, 'smileJobId');
    final callbackUrl = Uri.tryParse(
      requireText(initiation.callbackUrl, 'callbackUrl'),
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
          if (entry.value != 11 && entry.value != '11') {
            throw const SmileIdConfigurationException(
              'The backend did not create Smile job type 11.',
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

    return SmileIdDocumentJob(
      verificationId: requireText(initiation.verificationId, 'verificationId'),
      country: country,
      documentType: selectedType.smileIdWireValue,
      captureBothSides: selectedType.smileIdCaptureBothSides,
      userId: userId,
      jobId: jobId,
      callbackUrl: callbackUrl,
      extraPartnerParams: Map.unmodifiable(extra),
    );
  }

  final String verificationId;
  final String country;
  final String documentType;
  final bool captureBothSides;
  final String userId;
  final String jobId;
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
