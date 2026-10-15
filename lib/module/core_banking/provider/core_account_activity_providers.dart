import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_account_summary.dart';
import '../model/core_account_transactions.dart';
import '../service/core_account_service.dart';
import 'core_account_providers.dart';
import 'core_paged_rows.dart';

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
typedef CoreAccountHistory = PagedRows<CoreAccountTransaction>;

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

/// Re-reads the active Flex account's recent transactions after money may
/// have moved. Other visible ranges are invalidated so they also reload when
/// the customer returns to account history.
final refreshFlexTransactionHistoryProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    var accountNumber = ref
        .read(customerBankAccountsProvider)
        .data
        ?.activeFlexAccount
        ?.accountNumber;
    accountNumber ??=
        (await ref.read(customerBankAccountsProvider.notifier).load())
            .data
            ?.activeFlexAccount
            ?.accountNumber;
    if (accountNumber == null) return;

    for (final range in [
      CoreHistoryRange.last7Days,
      CoreHistoryRange.last60Days,
    ]) {
      ref.invalidate(
        coreAccountHistoryProvider((
          accountNumber: accountNumber,
          range: range,
        )),
      );
    }

    final key = (
      accountNumber: accountNumber,
      range: CoreHistoryRange.last30Days,
    );
    if (ref.exists(coreAccountHistoryProvider(key))) {
      await ref.read(coreAccountHistoryProvider(key).notifier).reload();
    } else {
      // A history provider without a listener may dispose before its queued
      // initial load. Read Core directly when the customer is off Home.
      await ref
          .read(coreAccountServiceProvider)
          .getAccountTransactions(accountNumber, CoreHistoryRange.last30Days);
    }
  },
);

class CoreAccountHistoryNotifier
    extends PagedRowsNotifier<CoreAccountTransaction> {
  CoreAccountHistoryNotifier(this.key);

  final CoreAccountHistoryKey key;

  @override
  int get pageSize => 20;

  @override
  String get loadFailure => "We couldn't load your transactions.";

  @override
  void watchScope() => ref.watch(authSessionProvider);

  @override
  Object? rowKey(CoreAccountTransaction row) => row.id;

  @override
  Future<NotifierState<PagedRead<CoreAccountTransaction>>> readPage(
    int page,
  ) async {
    final result = await ref
        .read(coreAccountServiceProvider)
        .getAccountTransactions(
          key.accountNumber,
          key.range,
          page: page,
          pageSize: pageSize,
        );
    final read = result.data;
    return read == null
        ? NotifierState.error(
            result.message ?? loadFailure,
            statusCode: result.statusCode,
          )
        : NotifierState.done((rows: read.rows, page: read.page));
  }
}
