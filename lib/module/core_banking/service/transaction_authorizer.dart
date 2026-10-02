import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the customer is asked to authorize.
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

/// The step every money-moving POST must pass first. A PIN or token it
/// collects never goes into a Core request body.
abstract interface class TransactionAuthorizer {
  /// True only when the customer authorized this transaction.
  Future<bool> authorize(BuildContext context, TransactionSummary summary);
}

/// Authorizes nothing. In place until security decides how transactions are
/// authorized (gate G2), so no money can move before then.
class DeniedTransactionAuthorizer implements TransactionAuthorizer {
  const DeniedTransactionAuthorizer();

  @override
  Future<bool> authorize(
    BuildContext context,
    TransactionSummary summary,
  ) async => false;
}

final transactionAuthorizerProvider = Provider<TransactionAuthorizer>(
  (ref) => const DeniedTransactionAuthorizer(),
);
