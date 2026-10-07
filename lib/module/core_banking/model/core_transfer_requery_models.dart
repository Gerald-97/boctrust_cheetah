import 'package:equatable/equatable.dart';

import 'core_json.dart';

/// Which Core re-query a transfer is tracked by.
enum CoreTransferKind { intrabank, interbank }

/// The identifier Core issued to re-query one transfer: `retrievalReference`
/// for intrabank moves, `transactionReference` for interbank transfers.
/// Never a BankOne receipt `reference` or `uniqueIdentifier`.
class CoreTrackingReference extends Equatable {
  const CoreTrackingReference(this.kind, this.value);

  final CoreTransferKind kind;
  final String value;

  static final _retrievalReference = RegExp(r'^[a-f0-9]{12}$');

  /// Whether the documented path parameter accepts [value].
  bool get isWellFormed => switch (kind) {
    CoreTransferKind.intrabank => _retrievalReference.hasMatch(value),
    CoreTransferKind.interbank => value.trim().isNotEmpty,
  };

  @override
  List<Object?> get props => [kind, value];
}

/// BankOne's live outcome for a transfer.
enum CoreLiveState { completed, failed, pending, reversed, unknown }

/// Provider status spellings, lower-cased, that mean the money moved.
///
/// `succesfulbutfeenottaken` is BankOne's own spelling, seen in a live
/// staging reply. Add a spelling only with a recorded backend reply.
const _successStatuses = {'successful', 'succesfulbutfeenottaken'};

/// Classifies BankOne's status and response code.
///
/// A reversal wins over everything. Otherwise only exact (trimmed,
/// case-insensitive) spellings count; `00` supports success but never makes
/// a missing or unfamiliar status complete, and a status that contradicts
/// its code is unknown.
CoreLiveState classifyProviderStatus({
  required String? status,
  required String? responseCode,
  bool isReversed = false,
}) {
  if (isReversed) return CoreLiveState.reversed;
  final text = status?.trim().toLowerCase();
  final code = responseCode?.trim() ?? '';
  if (_successStatuses.contains(text)) {
    return code.isEmpty || code == '00'
        ? CoreLiveState.completed
        : CoreLiveState.unknown;
  }
  return switch (text) {
    'failed' => code == '00' ? CoreLiveState.unknown : CoreLiveState.failed,
    'pending' => CoreLiveState.pending,
    _ => CoreLiveState.unknown,
  };
}

/// A live BankOne status query reply for one tracked transfer.
class CoreLiveTransferStatus extends Equatable {
  const CoreLiveTransferStatus({
    required this.state,
    required this.trackingReference,
    this.rawStatus,
    this.responseCode,
    this.isReversed = false,
  });

  factory CoreLiveTransferStatus.fromJson(CoreTransferKind kind, Object? json) {
    if (json is! Map) throw const FormatException('Invalid status reply.');
    final reference = coreText(
      json[kind == CoreTransferKind.intrabank
          ? 'retrievalReference'
          : 'transactionReference'],
    );
    if (reference == null) {
      throw const FormatException('Missing tracking reference.');
    }
    final status = coreText(json['status']);
    final code = coreText(json['responseCode']);
    final reversed =
        kind == CoreTransferKind.interbank && json['isReversed'] == true;
    return CoreLiveTransferStatus(
      state: classifyProviderStatus(
        status: status,
        responseCode: code,
        isReversed: reversed,
      ),
      trackingReference: CoreTrackingReference(kind, reference),
      rawStatus: status,
      responseCode: code,
      isReversed: reversed,
    );
  }

  final CoreLiveState state;
  final CoreTrackingReference trackingReference;
  final String? rawStatus;
  final String? responseCode;
  final bool isReversed;

  @override
  List<Object?> get props => [
    state,
    trackingReference,
    rawStatus,
    responseCode,
    isReversed,
  ];
}
