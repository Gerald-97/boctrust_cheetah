import 'package:equatable/equatable.dart';

import '../../../app/services.dart';

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

/// What an acknowledgement says happened to the money.
enum CoreAckOutcome { succeeded, failed, processing }

/// The body Core returns when it accepts a transfer. Acceptance is not
/// completion.
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

  /// BankOne answers `00` for an approved transaction, even when its status
  /// adds a caveat such as `SuccesfulButFeeNotTaken`. Any other code is a
  /// failure only when the status says so; otherwise it is still processing.
  CoreAckOutcome get outcome {
    if (responseCode == '00') return CoreAckOutcome.succeeded;
    final text = status?.toLowerCase() ?? '';
    return text.contains('fail') || text.contains('declin')
        ? CoreAckOutcome.failed
        : CoreAckOutcome.processing;
  }

  /// The reference to quote to support: Core's reference, or BankOne's
  /// unique identifier when the reference comes back empty.
  String? get displayReference => reference ?? uniqueIdentifier;

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
  recipientUnresolved(
    "We couldn't verify the receiving account. Check the details and try "
    'again.',
  ),
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

/// Classifies a money-moving response.
///
/// [interbank]: Core documents a `500` on interbank transfers as a failed
/// name enquiry or a rejected transfer, so nothing moved.
CoreSubmissionOutcome mapCoreSubmission(
  ServiceResponse<CoreTransferAck> response, {
  bool interbank = false,
}) {
  final ack = response.data;
  if (response.status == ServiceStatus.success && ack != null) {
    return AcceptedSubmission(ack);
  }
  // Never sent (Core not configured), so nothing can have moved.
  if (response.status == ServiceStatus.blocked) {
    return const RejectedSubmission(CoreRejection.other);
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
