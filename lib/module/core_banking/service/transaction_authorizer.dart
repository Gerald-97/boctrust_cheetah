/// What the customer is asked to authorize before a money-moving request.
class TransactionSummary {
  const TransactionSummary({
    required this.title,
    required this.amountDisplay,
    this.lines = const [],
  });

  final String title;
  final String amountDisplay;

  /// Label/value rows shown before authorization.
  final List<(String, String)> lines;
}
