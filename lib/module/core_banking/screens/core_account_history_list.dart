import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../home/provider/home_provider.dart';
import '../model/core_account_transactions.dart';
import '../provider/core_account_activity_providers.dart';
import 'core_transaction_detail_sheet.dart';
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Transactions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: BocSpace.xxs),
        Text(
          'Activity on this account',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.bocColors.textSecondary,
          ),
        ),
        const SizedBox(height: BocSpace.sm),
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
        const SizedBox(height: BocSpace.md),
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
          SizedBox(
            width: double.infinity,
            child: SurfaceCard(
              padding: const EdgeInsets.symmetric(
                horizontal: BocSpace.md,
                vertical: BocSpace.xxs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < history.rows.length; index++) ...[
                    if (index > 0)
                      Divider(color: context.bocColors.border, height: 1),
                    _historyRow(history.rows[index]),
                  ],
                ],
              ),
            ),
          ),
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
    final credit = row.type == CoreTransactionType.credit;
    final sign = credit ? '+' : '-';
    final amount = formatApiAmount(row.amount, currency: 'NGN');
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final accent = credit ? colors.successText : colors.info;
    final iconBackground = credit
        ? colors.successContainer
        : colors.infoContainer;
    final displayAmount = switch (amount) {
      _ when hidden => '₦ ••••••',
      null => 'Unavailable',
      final value => '$sign$value',
    };
    final date = row.date == null
        ? 'Date unavailable'
        : DateFormat('d MMM yyyy · h:mm a').format(row.date!.toLocal());
    return InkWell(
      onTap: () => showCoreTransactionDetailSheet(
        context,
        row,
        hidden: ref.read(homeBalanceHiddenProvider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: BocSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(BocRadius.sm),
              ),
              child: Icon(
                credit
                    ? IconsaxPlusLinear.arrow_down_1
                    : IconsaxPlusLinear.arrow_up,
                color: accent,
                size: 20,
              ),
            ),
            const SizedBox(width: BocSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.narration ?? (credit ? 'Money received' : 'Money sent'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: BocSpace.xxs),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          date,
                          maxLines: 2,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      if (row.reversed) ...[
                        const SizedBox(width: BocSpace.xs),
                        const CoreReversedIndicator(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: BocSpace.xs),
            Expanded(
              child: Text(
                displayAmount,
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.figures.copyWith(
                  color: credit && !row.reversed
                      ? colors.successText
                      : colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: BocSpace.xxs),
            Icon(
              IconsaxPlusLinear.arrow_right_3,
              size: 16,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
