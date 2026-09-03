import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

Map<String, Object?> _immutableMap(Object? value) => value is Map
    ? Map<String, Object?>.unmodifiable(Map<String, Object?>.from(value))
    : const <String, Object?>{};

/// Government identity number type accepted by the identity operation.
enum IdentityType {
  bvn('bvn', 'BVN'),
  nin('nin', 'NIN');

  const IdentityType(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// Exact length required for both BVN and NIN.
const kIdentityNumberLength = 11;

bool isValidIdentityNumber(String value) =>
    RegExp('^[0-9]{$kIdentityNumberLength}\$').hasMatch(value.trim());

/// Stage of a KYC flow.
///
/// [pendingReview] is the terminal client-side state for a successful
/// submission. Only refreshed profile/tier data may show a verified result:
/// the authoritative verdict arrives at the backend by provider webhook.
enum KycFlowStage {
  idle,
  initiating,
  awaitingProvider,
  selectingFile,
  requestingUpload,
  uploading,
  completing,
  pendingReview,
  failed,
}

class IdentityVerificationRequest {
  const IdentityVerificationRequest({
    required this.identityType,
    required this.identityNumber,
  });

  final IdentityType identityType;
  final String identityNumber;

  Map<String, Object?> toJson() => {
    'identityType': identityType.wireValue,
    'identityNumber': identityNumber,
  };
}

class GovernmentIdVerificationRequest {
  const GovernmentIdVerificationRequest({
    required this.documentType,
    this.documentNumber,
  });

  /// Backend-confirmed wire value. Never assembled from a product label — the
  /// canonical set is not published yet, so values must come from the API.
  final String documentType;
  final String? documentNumber;

  Map<String, Object?> toJson() => {
    'documentType': documentType,
    if (documentNumber != null && documentNumber!.isNotEmpty)
      'documentNumber': documentNumber,
  };
}

/// Response to an identity or government-ID initiation.
///
/// This records that a verification job was *created*. It is never evidence
/// that verification succeeded.
class KycInitiationData extends Equatable {
  const KycInitiationData({
    required this.verificationId,
    this.provider,
    this.product,
    this.environment,
    this.identityType,
    this.identityLastFour,
    this.documentType,
    this.smileUserId,
    this.smileJobId,
    this.callbackUrl,
    this.partnerParams = const {},
  });

  factory KycInitiationData.fromJson(Object? value) {
    final json = _map(value);
    return KycInitiationData(
      verificationId: json['verificationId']! as String,
      provider: json['provider'] as String?,
      product: json['product'] as String?,
      environment: json['environment'] as String?,
      identityType: json['identityType'] as String?,
      identityLastFour: json['identityLastFour'] as String?,
      documentType: json['documentType'] as String?,
      smileUserId: json['smileUserId'] as String?,
      smileJobId: json['smileJobId'] as String?,
      callbackUrl: json['callbackUrl'] as String?,
      partnerParams: _immutableMap(json['partnerParams']),
    );
  }

  final String verificationId;
  final String? provider;
  final String? product;
  final String? environment;
  final String? identityType;
  final String? identityLastFour;
  final String? documentType;

  /// Server-issued. Never constructed on the client.
  final String? smileUserId;
  final String? smileJobId;
  final String? callbackUrl;
  final Map<String, Object?> partnerParams;

  @override
  List<Object?> get props => [
    verificationId,
    provider,
    product,
    environment,
    identityType,
    identityLastFour,
    documentType,
    smileUserId,
    smileJobId,
    callbackUrl,
    partnerParams,
  ];
}

/// Client-side flow state for one KYC journey.
///
/// [verificationId] is preserved across a provider handoff and a resumed
/// conflict so a retry never orphans the job the backend already created.
class KycFlowData extends Equatable {
  const KycFlowData({
    this.stage = KycFlowStage.idle,
    this.verificationId,
    this.provider,
    this.providerEnvironment,
    this.identityLastFour,
    this.uploadExpiresAt,
  });

  final KycFlowStage stage;
  final String? verificationId;
  final String? provider;
  final String? providerEnvironment;
  final String? identityLastFour;
  final DateTime? uploadExpiresAt;

  KycFlowData copyWith({
    KycFlowStage? stage,
    String? verificationId,
    String? provider,
    String? providerEnvironment,
    String? identityLastFour,
    DateTime? uploadExpiresAt,
  }) => KycFlowData(
    stage: stage ?? this.stage,
    verificationId: verificationId ?? this.verificationId,
    provider: provider ?? this.provider,
    providerEnvironment: providerEnvironment ?? this.providerEnvironment,
    identityLastFour: identityLastFour ?? this.identityLastFour,
    uploadExpiresAt: uploadExpiresAt ?? this.uploadExpiresAt,
  );

  KycFlowData fromInitiation(KycInitiationData data, KycFlowStage stage) =>
      copyWith(
        stage: stage,
        verificationId: data.verificationId,
        provider: data.provider,
        providerEnvironment: data.environment,
        identityLastFour: data.identityLastFour,
      );

  @override
  List<Object?> get props => [
    stage,
    verificationId,
    provider,
    providerEnvironment,
    identityLastFour,
    uploadExpiresAt,
  ];
}
