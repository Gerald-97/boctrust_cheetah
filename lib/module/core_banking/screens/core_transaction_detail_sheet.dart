import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_account_transactions.dart';

/// Compact reversal marker shared by transaction rows and the detail sheet.
class CoreReversedIndicator extends StatelessWidget {
  const CoreReversedIndicator({this.showLabel = false, super.key});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return Tooltip(
      message: 'Reversed transaction',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.warningContainer,
          borderRadius: BorderRadius.circular(BocRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.refresh,
                size: 14,
                color: colors.warningText,
              ),
              if (showLabel) ...[
                const SizedBox(width: 4),
                Text(
                  'Reversed',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: colors.warningText),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the same Core transaction details from Home and account history.
Future<void> showCoreTransactionDetailSheet(
  BuildContext context,
  CoreAccountTransaction row, {
  required bool hidden,
}) async {
  final credit = row.type == CoreTransactionType.credit;
  final amount = formatApiAmount(row.amount, currency: 'NGN');
  final balance = formatApiAmount(row.balance, currency: 'NGN');
  final date = row.date == null
      ? 'Unavailable'
      : DateFormat('d MMM yyyy, h:mm a').format(row.date!.toLocal());
  await AppActionSheet.show<void>(
    context: context,
    builder: (sheet) {
      final colors = sheet.bocColors;
      return AppActionSheet(
        icon: credit
            ? IconsaxPlusLinear.arrow_down_1
            : IconsaxPlusLinear.arrow_up,
        iconColor: credit ? colors.successText : colors.info,
        iconBackground: credit ? colors.successContainer : colors.infoContainer,
        title: row.narration ?? (credit ? 'Money received' : 'Money sent'),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Amount',
                style: Theme.of(
                  sheet,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: BocSpace.xxs),
              SelectableText(
                hidden
                    ? '₦ ••••••'
                    : amount == null
                    ? 'Unavailable'
                    : '${credit ? '+' : '-'}$amount',
                style: Theme.of(sheet).textTheme.headlineMedium?.copyWith(
                  color: credit && !row.reversed
                      ? colors.successText
                      : colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (row.reversed) ...[
                const SizedBox(height: BocSpace.sm),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: CoreReversedIndicator(showLabel: true),
                ),
              ],
              const SizedBox(height: BocSpace.lg),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(BocRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BocSpace.md,
                    vertical: BocSpace.xs,
                  ),
                  child: Column(
                    children: [
                      _sheetRow(sheet, 'Date and time', date),
                      if (row.reference case final reference?) ...[
                        Divider(height: 1, color: colors.border),
                        _sheetRow(sheet, 'Reference', reference),
                      ],
                      if (row.balance != null) ...[
                        Divider(height: 1, color: colors.border),
                        _sheetRow(
                          sheet,
                          'Balance after',
                          hidden ? '₦ ••••••' : balance ?? 'Unavailable',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetRow(BuildContext context, String label, String value) {
  final colors = context.bocColors;
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: BocSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: BocSpace.md),
        Expanded(
          flex: 2,
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
