import 'package:equatable/equatable.dart';

import '../../core_banking/model/core_json.dart';
import '../../core_banking/model/core_money.dart';

/// A whole Kobo amount sent as digits, as a Naira decimal string, else null.
String? _naira(Object? kobo) {
  final text = coreText(kobo);
  return text != null && RegExp(r'^\d+$').hasMatch(text)
      ? koboToNaira(text)
      : null;
}

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
/// are documented in Kobo; custom and effective values are compared with
/// them, so all are read as Kobo.
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
      business: _naira(json['business$name']),
      custom: _naira(json['custom$name']),
      effective: _naira(json['effective$name']),
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
