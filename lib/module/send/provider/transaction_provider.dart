import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/transaction_models.dart';

const _historyUnavailable = 'Transaction history is not available yet.';

/// The customer's transaction history. No history contract exists yet, so
/// loading reports unavailability and nothing is listed that the server did
/// not return.
final transactionHistoryProvider =
    NotifierProvider<
      TransactionHistoryNotifier,
      NotifierState<List<TransactionRecord>>
    >(TransactionHistoryNotifier.new);

class TransactionHistoryNotifier
    extends Notifier<NotifierState<List<TransactionRecord>>> {
  @override
  NotifierState<List<TransactionRecord>> build() => const NotifierState.idle();

  Future<void> load() async =>
      state = const NotifierState.error(_historyUnavailable);

  void clear() => state = const NotifierState.idle();
}
