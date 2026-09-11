import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

Map<String, Object?> _section(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

String? _text(Object? value) {
  final result = value is String ? value.trim() : null;
  return (result == null || result.isEmpty) ? null : result;
}

DateTime? _utcTimestamp(Object? value) {
  final raw = _text(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw)?.toUtc();
}

/// State of one verification step, as published by `GET /users/me/kyc/status`.
///
/// [unknown] covers any value the server adds later. It is deliberately not
/// authorizing: only [success] may render a verified state, so a new server
/// value degrades to "not verified yet" rather than unlocking a financial
/// action on a status this build has never seen.
enum KycVerificationStatus {
  notStarted('not_started'),
  pending('pending'),
  success('success'),
  failed('failed'),
  unknown('');

  const KycVerificationStatus(this.wireValue);

  final String wireValue;

  static KycVerificationStatus fromWire(Object? value) {
    final raw = _text(value);
    for (final status in values) {
      if (status != unknown && status.wireValue == raw) return status;
    }
    return unknown;
  }

  /// The single place a verified UI state may be derived from.
  bool get isVerified => this == KycVerificationStatus.success;
}

/// The step the backend wants the user to complete next.
///
/// [unknown] follows the same rule as [KycVerificationStatus.unknown]: an
/// unrecognized action must not be presented as a completed journey.
enum KycNextAction {
  verifyIdentity('verify_identity'),
  verifyGovernmentId('verify_government_id'),
  uploadUtilityBill('upload_utility_bill'),
  complete('complete'),
  unknown('');

  const KycNextAction(this.wireValue);

  final String wireValue;

  static KycNextAction fromWire(Object? value) {
    final raw = _text(value);
    for (final action in values) {
      if (action != unknown && action.wireValue == raw) return action;
    }
    return unknown;
  }
}

/// Tier 1 identity (BVN/NIN) status.
class KycIdentityStatus extends Equatable {
  const KycIdentityStatus({
    required this.status,
    required this.hasBvnOrNin,
    required this.hasLivenessSelfie,
    this.identityType,
    this.identityLast4,
    this.failureReason,
    this.updatedAt,
  });

  factory KycIdentityStatus.fromJson(Object? value) {
    final json = _section(value);
    return KycIdentityStatus(
      status: KycVerificationStatus.fromWire(json['status']),
      hasBvnOrNin: json['hasBvnOrNin'] == true,
      hasLivenessSelfie: json['hasLivenessSelfie'] == true,
      identityType: _text(json['identityType']),
      identityLast4: _text(json['identityLast4']),
      failureReason: _text(json['failureReason']),
      updatedAt: _utcTimestamp(json['updatedAt']),
    );
  }

  final KycVerificationStatus status;

  /// Whether the backend holds a verified BVN or NIN for this user.
  final bool hasBvnOrNin;

  /// Whether the backend holds a liveness selfie. Pending BVN users may retry
  /// capture when the backend authorizes another Smile biometric job; this flag
  /// remains informational and is never treated as verification success.
  final bool hasLivenessSelfie;
  final String? identityType;
  final String? identityLast4;
  final String? failureReason;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    status,
    hasBvnOrNin,
    hasLivenessSelfie,
    identityType,
    identityLast4,
    failureReason,
    updatedAt,
  ];
}

/// Tier 2 government-document status.
class KycGovernmentIdStatus extends Equatable {
  const KycGovernmentIdStatus({
    required this.status,
    this.documentType,
    this.documentNumberLast4,
    this.failureReason,
    this.updatedAt,
  });

  factory KycGovernmentIdStatus.fromJson(Object? value) {
    final json = _section(value);
    return KycGovernmentIdStatus(
      status: KycVerificationStatus.fromWire(json['status']),
      documentType: _text(json['documentType']),
      documentNumberLast4: _text(json['documentNumberLast4']),
      failureReason: _text(json['failureReason']),
      updatedAt: _utcTimestamp(json['updatedAt']),
    );
  }

  final KycVerificationStatus status;
  final String? documentType;
  final String? documentNumberLast4;
  final String? failureReason;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [
    status,
    documentType,
    documentNumberLast4,
    failureReason,
    updatedAt,
  ];
}

/// Utility-bill review status.
class KycUtilityBillStatus extends Equatable {
  const KycUtilityBillStatus({
    required this.status,
    this.failureReason,
    this.reviewNotes,
    this.updatedAt,
  });

  factory KycUtilityBillStatus.fromJson(Object? value) {
    final json = _section(value);
    return KycUtilityBillStatus(
      status: KycVerificationStatus.fromWire(json['status']),
      failureReason: _text(json['failureReason']),
      reviewNotes: _text(json['reviewNotes']),
      updatedAt: _utcTimestamp(json['updatedAt']),
    );
  }

  final KycVerificationStatus status;
  final String? failureReason;

  /// Free text from a manual reviewer, shown to the user as-is.
  final String? reviewNotes;
  final DateTime? updatedAt;

  @override
  List<Object?> get props => [status, failureReason, reviewNotes, updatedAt];
}

/// Authoritative KYC state for the signed-in user.
///
/// This is the screen-level source of truth after an SDK submission or an app
/// resume. Neither backend initiation nor SDK success may be treated as
/// verification; only this endpoint and the refreshed tier/profile/Home
/// aggregates can move a card to verified.
class KycStatusData extends Equatable {
  const KycStatusData({
    required this.identity,
    required this.governmentId,
    required this.utilityBill,
    required this.nextAction,
    this.userId,
    this.tier,
  });

  factory KycStatusData.fromJson(Object? value) {
    final json = _map(value);
    return KycStatusData(
      userId: _text(json['userId']),
      tier: json['tier'] is num ? (json['tier']! as num).toInt() : null,
      identity: KycIdentityStatus.fromJson(json['identity']),
      governmentId: KycGovernmentIdStatus.fromJson(json['governmentId']),
      utilityBill: KycUtilityBillStatus.fromJson(json['utilityBill']),
      nextAction: KycNextAction.fromWire(json['nextAction']),
    );
  }

  final String? userId;
  final int? tier;
  final KycIdentityStatus identity;
  final KycGovernmentIdStatus governmentId;
  final KycUtilityBillStatus utilityBill;
  final KycNextAction nextAction;

  @override
  List<Object?> get props => [
    userId,
    tier,
    identity,
    governmentId,
    utilityBill,
    nextAction,
  ];
}
