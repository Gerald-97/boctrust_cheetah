import 'core_json.dart';

/// The history ranges the app offers. BankOne rejects a span it reads as
/// more than three months, even some that look narrower, so nothing longer
/// than 60 days is offered.
enum CoreHistoryRange {
  last7Days(7),
  last30Days(30),
  last60Days(60);

  const CoreHistoryRange(this.days);
  final int days;

  /// `fromDate`/`toDate` as `DD-MM-YYYY`, ending on [today].
  ({String fromDate, String toDate}) window(DateTime today) {
    final to = DateTime(today.year, today.month, today.day);
    return (
      fromDate: _format(to.subtract(Duration(days: days))),
      toDate: _format(to),
    );
  }

  static String _format(DateTime date) =>
      '${_two(date.day)}-${_two(date.month)}-${date.year}';
  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The rows of a transactions reply, untyped. The Core docs publish no item
/// schema (`items: {}`), so rows are not interpreted until a recorded reply
/// fixes their fields.
List<Object?> coreTransactionRows(Object? data) =>
    coreRows(data, const ['transactions']);
