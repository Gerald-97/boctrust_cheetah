import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_account_summary.dart';
import '../model/core_account_transactions.dart';
import '../service/core_account_service.dart';

/// The live summary of one account. Re-read when the session changes, so a
/// summary never outlives the customer it belongs to, and dropped when no
/// screen shows it.
final coreAccountSummaryProvider = FutureProvider.autoDispose
    .family<NotifierState<CoreAccountSummary>, String>((ref, accountNumber) {
      ref.watch(authSessionProvider);
      return ref
          .read(coreAccountServiceProvider)
          .getAccountSummary(accountNumber);
    });

/// The rows of one account's history read so far.
class CoreAccountHistory {
  const CoreAccountHistory({
    required this.rows,
    this.hasMore = false,
    this.loadingMore = false,
  });

  final List<CoreAccountTransaction> rows;
  final bool hasMore;
  final bool loadingMore;
}

typedef CoreAccountHistoryKey = ({
  String accountNumber,
  CoreHistoryRange range,
});

/// The live history of one account over one range, a page at a time. Keyed by
/// account and range and re-read when the session changes, so one account's or
/// customer's history never shows for another.
final coreAccountHistoryProvider = NotifierProvider.autoDispose
    .family<
      CoreAccountHistoryNotifier,
      NotifierState<CoreAccountHistory>,
      CoreAccountHistoryKey
    >(CoreAccountHistoryNotifier.new);

class CoreAccountHistoryNotifier
    extends Notifier<NotifierState<CoreAccountHistory>> {
  CoreAccountHistoryNotifier(this.key);

  final CoreAccountHistoryKey key;
  int _generation = 0;
  int _page = 1;

  @override
  NotifierState<CoreAccountHistory> build() {
    ref.watch(authSessionProvider);
    _generation++;
    Future.microtask(reload);
    return const NotifierState.loading();
  }

  Future<NotifierState<CoreTransactionPage>> _read(int page) => ref
      .read(coreAccountServiceProvider)
      .getAccountTransactions(key.accountNumber, key.range, page: page);

  /// Reads the first page again, dropping any later pages.
  Future<void> reload() async {
    final generation = ++_generation;
    final result = await _read(1);
    if (!ref.mounted || generation != _generation) return;
    final page = result.data;
    if (page == null) {
      state = NotifierState.error(
        result.message ?? "We couldn't load your transactions.",
        statusCode: result.statusCode,
      );
      return;
    }
    _page = 1;
    state = NotifierState.done(
      CoreAccountHistory(rows: page.rows, hasMore: page.page?.hasMore ?? false),
    );
  }

  /// Adds the next page, keeping the rows already shown. A failure leaves them
  /// as they are.
  Future<void> loadMore() async {
    final current = state.data;
    if (current == null || !current.hasMore || current.loadingMore) return;
    final generation = _generation;
    state = NotifierState.done(
      CoreAccountHistory(rows: current.rows, hasMore: true, loadingMore: true),
    );
    final result = await _read(_page + 1);
    if (!ref.mounted || generation != _generation) return;
    final page = result.data;
    if (page == null) {
      state = NotifierState.done(
        CoreAccountHistory(rows: current.rows, hasMore: true),
      );
      return;
    }
    _page++;
    final known = {for (final row in current.rows) row.id};
    state = NotifierState.done(
      CoreAccountHistory(
        rows: [
          ...current.rows,
          for (final row in page.rows)
            if (known.add(row.id)) row,
        ],
        hasMore: page.page?.hasMore ?? false,
      ),
    );
  }
}
