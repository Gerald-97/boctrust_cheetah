import 'package:equatable/equatable.dart';

import '../../core_banking/model/core_json.dart';

/// One limit: the tier's ceiling, the customer's own tighter cap if set, and
/// the value actually enforced. Naira decimal strings.
class TransactionLimit extends Equatable {
  const TransactionLimit({this.business, this.custom, this.effective});

  final String? business;
  final String? custom;
  final String? effective;

  @override
  List<Object?> get props => [business, custom, effective];
}

/// The caller's limits from `GET /me/transaction-limits`. The tier ceilings
/// are Naira decimal strings, as are the custom and effective values.
class TransactionLimits extends Equatable {
  const TransactionLimits({
    required this.tier,
    required this.singleTransfer,
    required this.singleBillPayment,
    required this.dailyTransfer,
  });

  factory TransactionLimits.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid limits.');
    final tier = json['tier'];
    if (tier is! int) throw const FormatException('Missing tier.');
    TransactionLimit limit(String name) => TransactionLimit(
      business: coreNaira(json['business$name']),
      custom: coreNaira(json['custom$name']),
      effective: coreNaira(json['effective$name']),
    );
    return TransactionLimits(
      tier: tier,
      singleTransfer: limit('SingleTransferLimit'),
      singleBillPayment: limit('SingleBillPaymentLimit'),
      dailyTransfer: limit('DailyTransferLimit'),
    );
  }

  final int tier;
  final TransactionLimit singleTransfer;
  final TransactionLimit singleBillPayment;
  final TransactionLimit dailyTransfer;

  @override
  List<Object?> get props => [
    tier,
    singleTransfer,
    singleBillPayment,
    dailyTransfer,
  ];
}
