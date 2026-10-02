import 'package:equatable/equatable.dart';

import '../../../app/services.dart';

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// The body Core returns when it accepts an intrabank transfer, interbank
/// transfer or bill payment. Acceptance is not completion.
class CoreTransferAck extends Equatable {
  const CoreTransferAck({
    this.responseCode,
    this.reference,
    this.message,
    this.status,
    this.uniqueIdentifier,
  });

  factory CoreTransferAck.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid transfer reply.');
    return CoreTransferAck(
      responseCode: _text(json['responseCode']),
      reference: _text(json['reference']),
      message: _text(json['message']),
      status: _text(json['status']),
      uniqueIdentifier: _text(json['uniqueIdentifier']),
    );
  }

  final String? responseCode;
  final String? reference;
  final String? message;
  final String? status;
  final String? uniqueIdentifier;

  @override
  List<Object?> get props => [
    responseCode,
    reference,
    message,
    status,
    uniqueIdentifier,
  ];
}

enum CoreRejection {
  validation('Please check the details and try again.'),
  insufficientFunds('Your balance is not enough for this amount.'),
  accountRestricted('Your account is restricted. Please contact support.'),
  accountMissing('This account is not available.'),
  referenceCollision('Something went wrong. You can try again.'),
  recipientUnresolved("We couldn't verify the receiving account."),
  other('This request was declined.');

  const CoreRejection(this.message);

  /// Customer-safe copy; server messages are not shown verbatim.
  final String message;
}

/// What happened to a money-moving request.
sealed class CoreSubmissionOutcome extends Equatable {
  const CoreSubmissionOutcome();
}

/// Core accepted the request. Completion is only ever shown from an
/// authoritative status (interbank) or a documented success code.
final class AcceptedSubmission extends CoreSubmissionOutcome {
  const AcceptedSubmission(this.ack);
  final CoreTransferAck ack;

  @override
  List<Object?> get props => [ack];
}

/// Core declined the request; no money moved.
final class RejectedSubmission extends CoreSubmissionOutcome {
  const RejectedSubmission(this.reason);
  final CoreRejection reason;
  String get message => reason.message;

  @override
  List<Object?> get props => [reason];
}

/// No reliable answer. The money may or may not have moved, so this is never
/// shown as success or failure and is never resent automatically.
final class UnknownSubmission extends CoreSubmissionOutcome {
  const UnknownSubmission();
  String get message =>
      "We couldn't confirm this transaction. Check your balance before "
      'trying again.';

  @override
  List<Object?> get props => [];
}

/// Classifies a money-moving response. [interbank] enables the documented
/// interbank `500` (receiver could not be resolved, or the transfer was
/// rejected), which is a definite decline rather than an unknown.
CoreSubmissionOutcome mapCoreSubmission(
  ServiceResponse<CoreTransferAck> response, {
  bool interbank = false,
}) {
  final ack = response.data;
  if (response.status == ServiceStatus.success && ack != null) {
    return AcceptedSubmission(ack);
  }
  final code = response.statusCode;
  return switch (code) {
    400 => RejectedSubmission(
      (response.message ?? '').toLowerCase().contains('insufficient')
          ? CoreRejection.insufficientFunds
          : CoreRejection.validation,
    ),
    403 => const RejectedSubmission(CoreRejection.accountRestricted),
    404 => const RejectedSubmission(CoreRejection.accountMissing),
    409 => const RejectedSubmission(CoreRejection.referenceCollision),
    500 when interbank => const RejectedSubmission(
      CoreRejection.recipientUnresolved,
    ),
    final int c when c >= 400 && c < 500 => const RejectedSubmission(
      CoreRejection.other,
    ),
    // No status, a server fault, or a 2xx that could not be read.
    _ => const UnknownSubmission(),
  };
}
