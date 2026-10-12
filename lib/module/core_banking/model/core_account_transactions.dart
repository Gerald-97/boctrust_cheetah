import 'core_json.dart';
import 'core_page.dart';

/// The history ranges the app offers. BankOne rejects a span it reads as
/// more than three months, even some that look narrower, so nothing longer
/// than 60 days is offered.
enum CoreHistoryRange {
  last7Days(7),
  last30Days(30),
  last60Days(60);

  const CoreHistoryRange(this.days);
  final int days;

  /// `fromDate`/`toDate` as `YYYY-MM-DD`, ending on [today].
  ({String fromDate, String toDate}) window(DateTime today) {
    final to = DateTime(today.year, today.month, today.day);
    return (
      fromDate: _format(to.subtract(Duration(days: days))),
      toDate: _format(to),
    );
  }

  static String _format(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';
  static String _two(int value) => value.toString().padLeft(2, '0');
}

enum CoreTransactionType { credit, debit }

/// One row of an account's history. Direction comes from [type]; [amount] is
/// never signed. Core's own banking reference is not kept.
class CoreAccountTransaction {
  const CoreAccountTransaction({
    required this.id,
    required this.type,
    required this.amount,
    this.date,
    this.balance,
    this.narration,
    this.reference,
    this.reversed = false,
  });

  final String id;
  final DateTime? date;
  final CoreTransactionType type;
  final String amount;

  /// The account balance after this row, in Naira.
  final String? balance;
  final String? narration;
  final String? reference;
  final bool reversed;

  /// Null for a row without an id, a known type or a readable amount.
  static CoreAccountTransaction? tryParse(Object? json) {
    if (json is! Map) return null;
    final id = coreId(json['id']);
    final type = switch (json['type']) {
      'credit' => CoreTransactionType.credit,
      'debit' => CoreTransactionType.debit,
      _ => null,
    };
    final amount = coreNaira(json['amount']);
    if (id == null || type == null || amount == null) return null;
    final date = json['date'];
    return CoreAccountTransaction(
      id: id,
      type: type,
      amount: amount,
      date: date is String ? DateTime.tryParse(date) : null,
      balance: coreNaira(json['balance']),
      narration: coreText(json['narration']),
      reference: coreText(json['reference']),
      reversed: json['reversed'] == true,
    );
  }
}

/// One page of an account's history. Unreadable rows are dropped.
class CoreTransactionPage {
  const CoreTransactionPage({required this.rows, this.page});

  factory CoreTransactionPage.fromJson(Object? json) => CoreTransactionPage(
    rows: [
      for (final row in coreRows(json, const ['transactions']))
        ?CoreAccountTransaction.tryParse(row),
    ],
    page: json is Map ? CorePage.tryParse(json['pagination']) : null,
  );

  final List<CoreAccountTransaction> rows;
  final CorePage? page;
}
