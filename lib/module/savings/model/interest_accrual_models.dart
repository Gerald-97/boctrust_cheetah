import 'package:equatable/equatable.dart';

import '../../core_banking/model/core_json.dart';
import '../../core_banking/model/core_page.dart';

/// One day's interest on Flex or on a savings plan. Amounts are Naira decimal
/// strings. [base] is what the day's interest was earned on: Flex `balance` or
/// plan `principalAmount`. [cumulativeInterest] is this month so far and
/// resets monthly.
class InterestAccrual extends Equatable {
  const InterestAccrual({
    this.date,
    this.base,
    this.ratePercent,
    this.interest,
    this.cumulativeInterest,
  });

  /// Null when [json] is not a day's accrual. A day whose figures cannot be
  /// read is kept, so it shows as unavailable rather than vanishing.
  static InterestAccrual? tryParse(Object? json, {required String baseKey}) {
    if (json is! Map) return null;
    final date = coreText(json['date']);
    final accrual = InterestAccrual(
      date: date == null ? null : DateTime.tryParse(date),
      base: coreNaira(json[baseKey]),
      ratePercent: coreText(json['ratePercent']),
      interest: coreNaira(json['interest']),
      cumulativeInterest: coreNaira(json['cumulativeInterest']),
    );
    return accrual.date == null && accrual.interest == null ? null : accrual;
  }

  final DateTime? date;
  final String? base;
  final String? ratePercent;
  final String? interest;
  final String? cumulativeInterest;

  @override
  List<Object?> get props => [
    date,
    base,
    ratePercent,
    interest,
    cumulativeInterest,
  ];
}

/// One page of accruals, newest first.
class InterestAccrualPage {
  const InterestAccrualPage({required this.accruals, this.page});

  factory InterestAccrualPage.fromJson(
    Object? json, {
    required String baseKey,
  }) => InterestAccrualPage(
    accruals: [
      for (final row in coreRows(json, const ['accruals']))
        ?InterestAccrual.tryParse(row, baseKey: baseKey),
    ],
    page: json is Map ? CorePage.tryParse(json['pagination']) : null,
  );

  final List<InterestAccrual> accruals;
  final CorePage? page;
}
