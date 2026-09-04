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

/// Government-issued document accepted for Tier 2 verification.
///
/// Wire values are backend-confirmed. They are lower snake case and must be
/// emitted exactly.
enum GovernmentIdDocumentType {
  voterId('voter_id', "Voter's card"),
  driversLicense('drivers_license', "Driver's licence"),
  internationalPassport('international_passport', 'International passport'),
  ninSlip('nin_slip', 'NIN slip');

  const GovernmentIdDocumentType(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// ISO 3166-1 alpha-2 country of issue. Nigeria is the only market today.
const kDefaultDocumentCountry = 'NG';

class GovernmentIdVerificationRequest {
  const GovernmentIdVerificationRequest({
    required this.documentType,
    this.documentNumber,
    this.country = kDefaultDocumentCountry,
  });

  final GovernmentIdDocumentType documentType;
  final String? documentNumber;
  final String country;

  Map<String, Object?> toJson() => {
    'documentType': documentType.wireValue,
    'country': country,
    if (documentNumber != null && documentNumber!.trim().isNotEmpty)
      'documentNumber': documentNumber!.trim(),
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
    this.sdkJobType,
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
      // `jobType` is the documented alias; either may carry the value.
      sdkJobType: json['sdkJobType'] as String? ?? json['jobType'] as String?,
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

  /// Smile ID job type for this verification, chosen by the backend.
  ///
  /// The client passes it through to the SDK rather than hard-coding a job
  /// type, so a backend product change does not require an app release.
  final String? sdkJobType;
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
    sdkJobType,
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

/// Metering arrangement on a utility bill.
enum UtilityType {
  prePaid('PrePaid', 'Prepaid'),
  postPaid('PostPaid', 'Postpaid');

  const UtilityType(this.wireValue, this.label);

  /// Emitted exactly as documented — the API is case-sensitive here.
  final String wireValue;
  final String label;
}

/// Maximum accepted utility-bill size, enforced before an upload URL is
/// requested so an oversized file never consumes a signed link.
const kUtilityBillMaxBytes = 10485760; // 10 MiB

const kUtilityBillContentTypes = <String>{
  'application/pdf',
  'image/jpeg',
  'image/png',
};

const kUtilityBillExtensions = <String>['pdf', 'jpg', 'jpeg', 'png'];

/// Maps a file extension to the content type the API expects.
String? contentTypeForExtension(String? extension) =>
    switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };

/// A user-selected utility bill, held in memory until it is uploaded.
class SelectedUtilityBill extends Equatable {
  const SelectedUtilityBill({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final List<int> bytes;

  int get sizeInBytes => bytes.length;

  @override
  List<Object?> get props => [fileName, contentType, sizeInBytes];
}

class UtilityBillInitiationRequest {
  const UtilityBillInitiationRequest({
    required this.residentialAddress,
    required this.contentType,
    this.state,
    this.lga,
    this.utilityProvider,
    this.utilityType,
    this.utilityNumber,
    this.billIssueDate,
    this.originalFileName,
    this.fileSizeBytes,
  });

  final String residentialAddress;
  final String contentType;
  final String? state;
  final String? lga;
  final String? utilityProvider;
  final UtilityType? utilityType;
  final String? utilityNumber;
  final DateTime? billIssueDate;
  final String? originalFileName;
  final int? fileSizeBytes;

  Map<String, Object?> toJson() => {
    'residentialAddress': residentialAddress,
    'contentType': contentType,
    if (_has(state)) 'state': state,
    if (_has(lga)) 'lga': lga,
    if (_has(utilityProvider)) 'utilityProvider': utilityProvider,
    if (utilityType != null) 'utilityType': utilityType!.wireValue,
    if (_has(utilityNumber)) 'utilityNumber': utilityNumber,
    if (billIssueDate != null)
      'billIssueDate': billIssueDate!.toUtc().toIso8601String(),
    if (_has(originalFileName)) 'originalFileName': originalFileName,
    if (fileSizeBytes != null) 'fileSizeBytes': fileSizeBytes,
  };

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}

/// Response to a utility-bill upload initiation.
///
/// Carries the short-lived signed URL and the exact headers the storage
/// endpoint requires. Both headers must be sent verbatim or the PUT is
/// rejected.
class UtilityBillUploadTarget extends Equatable {
  const UtilityBillUploadTarget({
    required this.verificationId,
    required this.uploadUrl,
    required this.requiredHeaders,
    this.status,
    this.storageKey,
    this.expiresInSeconds,
  });

  factory UtilityBillUploadTarget.fromJson(Object? value) {
    final json = _map(value);
    final uploadUrl = json['uploadUrl']! as String;
    final parsed = Uri.tryParse(uploadUrl);
    if (parsed == null || parsed.scheme != 'https' || !parsed.hasAuthority) {
      throw const FormatException('Upload URL must be HTTPS.');
    }

    final headers = <String, String>{};
    final rawHeaders = json['requiredHeaders'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, dynamic value) {
        if (value != null) headers['$key'] = '$value';
      });
    }

    return UtilityBillUploadTarget(
      verificationId: json['verificationId']! as String,
      uploadUrl: uploadUrl,
      requiredHeaders: Map<String, String>.unmodifiable(headers),
      status: json['status'] as String?,
      storageKey: json['key'] as String? ?? json['storageKey'] as String?,
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt(),
    );
  }

  final String verificationId;
  final String uploadUrl;
  final Map<String, String> requiredHeaders;
  final String? status;

  /// Storage object key. Diagnostic only — never shown to the user.
  final String? storageKey;
  final int? expiresInSeconds;

  Uri get uri => Uri.parse(uploadUrl);

  /// Headers actually sent with the PUT.
  ///
  /// Server-side encryption is required by the storage bucket policy; it is
  /// added when the API did not already specify it.
  Map<String, String> headersFor(String contentType) => {
    'Content-Type': contentType,
    'x-amz-server-side-encryption': 'AES256',
    ...requiredHeaders,
  };

  @override
  List<Object?> get props => [
    verificationId,
    uploadUrl,
    requiredHeaders,
    status,
    storageKey,
    expiresInSeconds,
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
    this.selectedBill,
    this.uploadCompleted = false,
  });

  final KycFlowStage stage;
  final String? verificationId;
  final String? provider;
  final String? providerEnvironment;
  final String? identityLastFour;
  final DateTime? uploadExpiresAt;

  /// Retained while the screen is mounted so a failed completion can be
  /// retried without asking the user to pick the file again.
  final SelectedUtilityBill? selectedBill;

  /// True once the signed PUT succeeded. Completion may only be retried —
  /// rather than restarted — while this holds.
  final bool uploadCompleted;

  KycFlowData copyWith({
    KycFlowStage? stage,
    String? verificationId,
    String? provider,
    String? providerEnvironment,
    String? identityLastFour,
    DateTime? uploadExpiresAt,
    SelectedUtilityBill? selectedBill,
    bool? uploadCompleted,
  }) => KycFlowData(
    stage: stage ?? this.stage,
    verificationId: verificationId ?? this.verificationId,
    provider: provider ?? this.provider,
    providerEnvironment: providerEnvironment ?? this.providerEnvironment,
    identityLastFour: identityLastFour ?? this.identityLastFour,
    uploadExpiresAt: uploadExpiresAt ?? this.uploadExpiresAt,
    selectedBill: selectedBill ?? this.selectedBill,
    uploadCompleted: uploadCompleted ?? this.uploadCompleted,
  );

  /// Clears the verification context so a lapsed link is replaced by a fresh
  /// initiation rather than reused.
  KycFlowData withoutUploadTarget() => KycFlowData(
    stage: stage,
    provider: provider,
    providerEnvironment: providerEnvironment,
    identityLastFour: identityLastFour,
    selectedBill: selectedBill,
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
    selectedBill,
    uploadCompleted,
  ];
}
