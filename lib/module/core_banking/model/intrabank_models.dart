import 'package:equatable/equatable.dart';

/// Which way money moves between the customer's own accounts. BocFlex is
/// always one side.
enum OwnAccountDirection {
  /// BocFlex → a savings product (`POST /me/intrabank/transfers/own`).
  toSavings,

  /// A savings product → BocFlex (`POST /me/intrabank/withdrawals`).
  toFlex,
}

/// Maximum narration length Core accepts.
const kNarrationMaxLength = 100;

/// One move between the customer's own accounts, as reviewed.
class OwnAccountMoveDraft extends Equatable {
  const OwnAccountMoveDraft({
    required this.direction,
    required this.productCode,
    required this.amountKobo,
    this.narration,
  });

  final OwnAccountDirection direction;

  /// The non-Flex product account on the other side.
  final String productCode;

  /// Integer Kobo string from `parseNairaToKobo`.
  final String amountKobo;
  final String? narration;

  Map<String, Object?> toJson() {
    final note = narration?.trim() ?? '';
    return {
      direction == OwnAccountDirection.toSavings
              ? 'toProductCode'
              : 'fromProductCode':
          productCode,
      'amount': amountKobo,
      if (note.isNotEmpty) 'narration': note,
    };
  }

  @override
  List<Object?> get props => [direction, productCode, amountKobo, narration];
}
