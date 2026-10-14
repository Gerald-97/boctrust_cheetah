import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';

typedef SavingsPlanProgress = ({double fraction, bool reached});

/// How far a plan's principal is toward its target, for display only. Null
/// unless both are Core decimal strings and the target is above zero.
SavingsPlanProgress? savingsPlanProgress({String? principal, String? target}) {
  final saved = double.tryParse(principal ?? '');
  final goal = double.tryParse(target ?? '');
  if (saved == null || goal == null || goal <= 0) return null;
  return (fraction: (saved / goal).clamp(0.0, 1.0), reached: saved >= goal);
}

/// The plan's headline: status, balance, rate and progress on its product tint.
class SavingsPlanHero extends StatelessWidget {
  const SavingsPlanHero({
    required this.status,
    required this.amount,
    required this.accent,
    required this.container,
    required this.icon,
    required this.onDeposit,
    this.rate,
    this.progressLabel,
    this.progress,
    super.key,
  });

  final String status;
  final String amount;
  final Color accent;
  final Color container;
  final IconData icon;
  final VoidCallback onDeposit;
  final String? rate;
  final String? progressLabel;
  final SavingsPlanProgress? progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final progress = this.progress;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BocSpace.lg),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(BocRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, color: accent, size: 22),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BocSpace.sm,
                  vertical: BocSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border.all(color: accent),
                  borderRadius: BorderRadius.circular(BocRadius.pill),
                ),
                child: Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.md),
          Text('Plan balance', style: theme.textTheme.bodySmall),
          const SizedBox(height: BocSpace.xxs),
          BocMoneyText(amount, semanticsLabel: 'Plan balance'),
          if (rate != null) ...[
            const SizedBox(height: BocSpace.xxs),
            Text(
              rate!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: BocSpace.md),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(BocRadius.pill),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: BocSpace.xs,
                      color: accent,
                      backgroundColor: colors.surface,
                    ),
                  ),
                  if (progressLabel != null) ...[
                    const SizedBox(height: BocSpace.xs),
                    Text(progressLabel!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: BocSpace.lg),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onDeposit,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, BocSpace.minTouch),
                backgroundColor: colors.surface,
                foregroundColor: accent,
                side: BorderSide(color: accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
              ),
              icon: const Icon(IconsaxPlusLinear.add_circle, size: 20),
              label: const Text('Deposit'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card of label/value rows. Values stack under their labels at
/// large text sizes, the same threshold `BocSummaryGrid` uses.
class SavingsFactGroup extends StatelessWidget {
  const SavingsFactGroup({required this.title, required this.rows, super.key});

  final String title;
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    Widget row(({String label, String value}) item) {
      final label = Text(item.label, style: theme.textTheme.bodySmall);
      final value = Text(
        item.value,
        style: theme.textTheme.titleSmall,
        textAlign: stacked ? TextAlign.start : TextAlign.end,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: BocSpace.sm),
        child: MergeSemantics(
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label,
                    const SizedBox(height: BocSpace.xxs),
                    value,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: label),
                    const SizedBox(width: BocSpace.md),
                    Flexible(child: value),
                  ],
                ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: BocSpace.xs),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: BocSpace.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BocRadius.md),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, color: colors.border),
                row(rows[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One plan event: an icon, what happened, when, and the amount if it moved
/// money.
class SavingsActivityRow extends StatelessWidget {
  const SavingsActivityRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.container,
    this.date,
    this.amount,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final Color container;
  final String? date;
  final String? amount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BocSpace.minTouch),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BocSpace.md,
              vertical: BocSpace.sm,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: container,
                    borderRadius: BorderRadius.circular(BocRadius.sm),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(icon, size: 20, color: accent),
                  ),
                ),
                const SizedBox(width: BocSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.bodyMedium),
                      if (date != null)
                        Text(date!, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (amount != null) ...[
                  const SizedBox(width: BocSpace.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.36,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        amount!,
                        style: theme.textTheme.titleSmall?.figures.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
                if (onTap != null) ...[
                  const SizedBox(width: BocSpace.xs),
                  Icon(
                    IconsaxPlusLinear.arrow_right_3,
                    size: 14,
                    color: colors.textTertiary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A short notice on the info tint, for facts the customer should read before
/// acting.
class SavingsCallout extends StatelessWidget {
  const SavingsCallout({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BocSpace.md),
      decoration: BoxDecoration(
        color: colors.infoContainer,
        borderRadius: BorderRadius.circular(BocRadius.md),
      ),
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.info),
            const SizedBox(width: BocSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: BocSpace.xxs),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
