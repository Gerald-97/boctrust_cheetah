import 'package:equatable/equatable.dart';

/// Maximum narration length Core accepts.
const kNarrationMaxLength = 100;

/// One transfer from BocFlex to another BOCTRUST customer, as reviewed.
class BoctrustTransferDraft extends Equatable {
  const BoctrustTransferDraft({
    required this.toAccountNumber,
    required this.amountKobo,
    this.narration,
  });

  /// Ten-digit BOCTRUST account number.
  final String toAccountNumber;

  /// Integer Kobo string from `parseNairaToKobo`.
  final String amountKobo;
  final String? narration;

  Map<String, Object?> toJson() {
    final note = narration?.trim() ?? '';
    return {
      'toAccountNumber': toAccountNumber,
      'amount': amountKobo,
      if (note.isNotEmpty) 'narration': note,
    };
  }

  @override
  List<Object?> get props => [toAccountNumber, amountKobo, narration];
}
