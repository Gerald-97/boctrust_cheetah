import 'package:equatable/equatable.dart';

import '../../core_banking/model/core_json.dart';

/// The BocFlex interest summary. Amounts are Naira decimal strings: this
/// month's accrual is paid on the 1st of next month.
class FlexInterest extends Equatable {
  const FlexInterest({
    this.ratePercent,
    this.currentMonthAccruedInterest,
    this.totalInterestEarned,
  });

  factory FlexInterest.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Missing interest.');
    return FlexInterest(
      ratePercent: coreText(json['ratePercent']),
      currentMonthAccruedInterest: coreNaira(
        json['currentMonthAccruedInterest'],
      ),
      totalInterestEarned: coreNaira(json['totalInterestEarned']),
    );
  }

  final String? ratePercent;
  final String? currentMonthAccruedInterest;
  final String? totalInterestEarned;

  @override
  List<Object?> get props => [
    ratePercent,
    currentMonthAccruedInterest,
    totalInterestEarned,
  ];
}
