import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../home/provider/home_provider.dart';
import '../model/core_account_transactions.dart';
import '../provider/core_account_activity_providers.dart';
import 'paged_rows_footer.dart';

/// One Core account's transactions: range chips, rows and the Show more
/// footer. Meant for a ListView's children, so it has no scroll of its own.
class CoreAccountHistoryList extends ConsumerStatefulWidget {
  const CoreAccountHistoryList({
    super.key,
    required this.accountNumber,
    this.onRangeChanged,
  });

  final String accountNumber;

  /// Told the range being shown, so a pull-to-refresh can reload that range.
  final ValueChanged<CoreHistoryRange>? onRangeChanged;

  @override
  ConsumerState<CoreAccountHistoryList> createState() =>
      _CoreAccountHistoryListState();
}

class _CoreAccountHistoryListState
    extends ConsumerState<CoreAccountHistoryList> {
  CoreHistoryRange _range = CoreHistoryRange.last30Days;

  @override
  Widget build(BuildContext context) {
    final key = (accountNumber: widget.accountNumber, range: _range);
    final state = ref.watch(coreAccountHistoryProvider(key));
    final history = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BocChoiceChips<CoreHistoryRange>(
          options: const [
            (value: CoreHistoryRange.last7Days, label: '7 days'),
            (value: CoreHistoryRange.last30Days, label: '30 days'),
            (value: CoreHistoryRange.last60Days, label: '60 days'),
          ],
          selected: {_range},
          onChanged: (next) {
            setState(() => _range = next.first);
            widget.onRangeChanged?.call(_range);
          },
        ),
        const SizedBox(height: BocSpace.sm),
        if (history == null && state.isError)
          ApiStateCard(
            title: 'Transactions unavailable',
            message: state.message ?? "We couldn't load your transactions.",
            tone: ApiStateTone.error,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(coreAccountHistoryProvider(key)),
          )
        else if (history == null)
          const ApiLoadingSection(label: 'Loading your transactions')
        else if (history.rows.isEmpty)
          const ApiStateCard(
            title: 'Transactions',
            message: 'No transactions in this period.',
            tone: ApiStateTone.info,
          )
        else ...[
          for (final row in history.rows) _historyRow(row),
          PagedRowsFooter(
            rows: history,
            onShowMore: () =>
                ref.read(coreAccountHistoryProvider(key).notifier).loadMore(),
          ),
        ],
      ],
    );
  }

  Widget _historyRow(CoreAccountTransaction row) {
    final sign = row.type == CoreTransactionType.credit ? '+' : '-';
    final amount = formatApiAmount(row.amount, currency: 'NGN');
    final hidden = ref.watch(homeBalanceHiddenProvider);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(row.narration ?? 'Transaction'),
      subtitle: Text(
        [
          if (row.date case final date?)
            DateFormat('d MMM, h:mm a').format(date.toLocal())
          else
            'Date unavailable',
          if (row.reversed) 'Reversed',
        ].join(' · '),
      ),
      trailing: Text(switch (amount) {
        _ when hidden => '₦ ••••••',
        null => 'Unavailable',
        final amount => '$sign$amount',
      }),
    );
  }
}
