import 'package:equatable/equatable.dart';

/// The limits a customer chose to change, as the API strings to send. A
/// limit left null is unchanged and never sent.
///
/// The Swagger does not state these values' unit; the limits screen converts
/// what the customer typed, and the edit capability stays staging-only until
/// staging confirms it.
class TransactionLimitDraft extends Equatable {
  const TransactionLimitDraft({
    this.singleTransferLimit,
    this.singleBillPaymentLimit,
    this.dailyTransferLimit,
  });

  final String? singleTransferLimit;
  final String? singleBillPaymentLimit;
  final String? dailyTransferLimit;

  bool get isEmpty =>
      singleTransferLimit == null &&
      singleBillPaymentLimit == null &&
      dailyTransferLimit == null;

  /// Only the changed limits, as Swagger asks.
  Map<String, Object?> toJson() => {
    'singleTransferLimit': ?singleTransferLimit,
    'singleBillPaymentLimit': ?singleBillPaymentLimit,
    'dailyTransferLimit': ?dailyTransferLimit,
  };

  @override
  List<Object?> get props => [
    singleTransferLimit,
    singleBillPaymentLimit,
    dailyTransferLimit,
  ];
}
