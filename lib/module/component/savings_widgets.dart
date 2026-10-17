part of '../app_flow/app_ui.dart';

/// Two-column label/value tiles for server-supplied facts about an account.
class GridViewInfo extends StatelessWidget {
  const GridViewInfo({required this.items, super.key});

  final List<({String label, String value})> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    return ResponsiveTiles(
      maxColumns: 2,
      minTileWidth: 150,
      spacing: BocSpace.xs,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(BocSpace.md),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BocRadius.md),
            ),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: BocSpace.xxs),
                  Text(item.value, style: theme.textTheme.titleSmall?.figures),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The Flex entry on the Save hub: gold card with the live balance.
class FlexSavingsTile extends StatelessWidget {
  const FlexSavingsTile({
    required this.title,
    required this.balance,
    required this.hidden,
    required this.onTap,
    this.accountNumber,
    this.rate,
    this.frozen = false,
    super.key,
  });

  final String title;

  /// Preformatted balance, or null when none has been returned yet.
  final String? balance;
  final bool hidden;
  final VoidCallback onTap;
  final String? accountNumber;
  final String? rate;
  final bool frozen;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final value = balance;
    final number = accountNumber;
    final accountHint = number == null
        ? null
        : 'Account •••• ${number.substring(number.length > 4 ? number.length - 4 : 0)}';
    return Material(
      color: colors.flexAccent,
      borderRadius: BorderRadius.circular(BocRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BocSpace.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: BocColors.navy,
                      ),
                    ),
                    const SizedBox(height: BocSpace.xs),
                    Text(
                      'Available balance',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: BocColors.navy,
                      ),
                    ),
                    const SizedBox(height: BocSpace.xxs),
                    if (value == null)
                      Text(
                        'Balance unavailable',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: BocColors.navy,
                        ),
                      )
                    else
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: BocMoneyText(
                          value,
                          hidden: hidden,
                          semanticsLabel: '$title balance',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: BocColors.navy,
                          ),
                        ),
                      ),
                    if (rate != null || accountHint != null || frozen) ...[
                      const SizedBox(height: BocSpace.sm),
                      Wrap(
                        spacing: BocSpace.sm,
                        runSpacing: BocSpace.xxs,
                        children: [
                          // The tile is always light, so the label takes navy.
                          if (frozen) const FrozenLabel(color: BocColors.navy),
                          if (rate != null)
                            Text(
                              '$rate% p.a.',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: BocColors.navy,
                              ),
                            ),
                          if (accountHint != null)
                            Text(
                              accountHint,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: BocColors.navy,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                IconsaxPlusLinear.arrow_right_3,
                color: BocColors.navy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An owned savings account on the Save hub, with only published product facts.
class OwnedSavingsTile extends StatelessWidget {
  const OwnedSavingsTile({
    required this.title,
    required this.balance,
    required this.hidden,
    this.accountNumber,
    required this.status,
    required this.icon,
    required this.accent,
    required this.container,
    this.rate,
    this.tenureDays,
    this.createdItemCount,
    this.createdItemLabel,
    this.onTap,
    super.key,
  });

  final String title;
  final String? balance;
  final bool hidden;
  final String? accountNumber;
  final String status;
  final IconData icon;
  final Color accent;
  final Color container;
  final String? rate;
  final int? tenureDays;
  final int? createdItemCount;
  final String? createdItemLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final number = accountNumber;
    final suffix = number?.substring(number.length > 4 ? number.length - 4 : 0);
    return SurfaceCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: container,
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, color: accent, size: 22),
                ),
              ),
              const SizedBox(width: BocSpace.sm),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              if (onTap != null)
                Icon(
                  IconsaxPlusLinear.arrow_right_3,
                  size: 20,
                  color: colors.textTertiary,
                ),
            ],
          ),
          const SizedBox(height: BocSpace.sm),
          Text('Available balance', style: theme.textTheme.bodySmall),
          const SizedBox(height: BocSpace.xxs),
          Text(
            hidden ? '₦ ••••••' : balance ?? 'Balance unavailable',
            style: theme.textTheme.titleMedium?.figures,
          ),
          const SizedBox(height: BocSpace.sm),
          Wrap(
            spacing: BocSpace.xs,
            runSpacing: BocSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (suffix != null)
                Text(
                  'Account •••• $suffix',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              if (status == 'Frozen')
                const FrozenLabel()
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: status == 'Active'
                            ? colors.successText
                            : colors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox.square(dimension: 6),
                    ),
                    const SizedBox(width: BocSpace.xxs),
                    Text(
                      status,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: status == 'Active'
                            ? colors.successText
                            : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              if (rate != null)
                Text(
                  '$rate% p.a.',
                  style: theme.textTheme.labelMedium?.copyWith(color: accent),
                ),
              if (tenureDays != null)
                Text(
                  tenureDays == 1 ? '1-day term' : '$tenureDays-day term',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              if (createdItemCount != null && createdItemLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BocSpace.xs,
                    vertical: BocSpace.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: container,
                    borderRadius: BorderRadius.circular(BocRadius.pill),
                  ),
                  child: Text(
                    '$createdItemCount ${createdItemLabel!}${createdItemCount == 1 ? '' : 's'}',
                    style: theme.textTheme.labelMedium?.copyWith(color: accent),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One Core catalogue product on the Save hub: name, description and the
/// facts the server published for it, such as rate and tenure.
class BankProductCard extends StatelessWidget {
  const BankProductCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.container,
    required this.onTap,
    this.description,
    this.facts = const [],
    super.key,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Color accent;
  final Color container;

  /// Preformatted facts shown as chips under the description.
  final List<({IconData icon, String label})> facts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final text = description;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(BocRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(BocSpace.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(BocRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: container,
                      borderRadius: BorderRadius.circular(BocRadius.sm),
                    ),
                    child: SizedBox.square(
                      dimension: 44,
                      child: Icon(icon, color: accent),
                    ),
                  ),
                  const SizedBox(width: BocSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        if (text != null) ...[
                          const SizedBox(height: BocSpace.xxs),
                          Text(
                            text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: BocSpace.xs),
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Icon(
                        IconsaxPlusLinear.arrow_right_3,
                        size: 20,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: BocSpace.sm),
                Wrap(
                  spacing: BocSpace.xs,
                  runSpacing: BocSpace.xs,
                  children: [
                    for (final fact in facts)
                      _ProductFactChip(icon: fact.icon, label: fact.label),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductFactChip extends StatelessWidget {
  const _ProductFactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BocSpace.xs,
        vertical: BocSpace.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(BocRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: BocSpace.xxs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.textMain),
          ),
        ],
      ),
    );
  }
}

/// A savings account tile shape while balances load.
class SavingsAccountSkeleton extends StatelessWidget {
  const SavingsAccountSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return Semantics(
      label: 'Loading your savings accounts',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(BocSpace.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BocRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              AppShimmerBlock(width: 170, height: 18),
              SizedBox(height: BocSpace.md),
              AppShimmerBlock(width: 210, height: 30),
              SizedBox(height: BocSpace.md),
              AppShimmerBlock(width: 120, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder rows while the product catalogue loads.
class BankProductSkeleton extends StatelessWidget {
  const BankProductSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    Widget bar(double width, double height) =>
        AppShimmerBlock(width: width, height: height);
    return Semantics(
      label: 'Loading savings products',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(BocSpace.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(BocRadius.md),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(44, 44),
              const SizedBox(width: BocSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(140, 14),
                    const SizedBox(height: BocSpace.xs),
                    bar(double.infinity, 10),
                    const SizedBox(height: BocSpace.xxs),
                    bar(180, 10),
                    const SizedBox(height: BocSpace.sm),
                    Row(
                      children: [
                        bar(72, 22),
                        const SizedBox(width: BocSpace.xs),
                        bar(64, 22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state for a section with nothing to list: a soft icon badge, a
/// title, a short explanation and at most one action.
class SavingsEmptyState extends StatelessWidget {
  const SavingsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final label = actionLabel;
    final action = onAction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: BocSpace.lg,
        vertical: BocSpace.xl,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.goldPale,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(BocSpace.xs),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 56,
                  child: Icon(icon, size: 28, color: colors.goldStrong),
                ),
              ),
            ),
          ),
          const SizedBox(height: BocSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: BocSpace.xxs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
          ),
          if (label != null && action != null) ...[
            const SizedBox(height: BocSpace.sm),
            TextButton.icon(
              onPressed: action,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: const Icon(IconsaxPlusLinear.refresh, size: 18),
              label: Text(label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Flex detail hero: gold gradient with the live balance and its actions.
class FlexHeroCard extends StatelessWidget {
  const FlexHeroCard({
    required this.balance,
    required this.hidden,
    required this.onToggle,
    required this.primary,
    this.secondary,
    super.key,
  });

  final String? balance;
  final bool hidden;
  final VoidCallback onToggle;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final value = balance;
    final secondary = this.secondary;
    return Container(
      padding: const EdgeInsets.all(BocSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BocRadius.md),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.flexContainer, colors.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available balance', style: theme.textTheme.bodySmall),
          Row(
            children: [
              Flexible(
                child: value == null
                    ? Text('—', style: theme.textTheme.displayMedium)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: BocMoneyText(
                          value,
                          hidden: hidden,
                          semanticsLabel: 'Flex balance',
                        ),
                      ),
              ),
              IconButton(
                tooltip: hidden ? 'Show balance' : 'Hide balance',
                onPressed: onToggle,
                icon: Icon(
                  hidden ? IconsaxPlusLinear.eye_slash : IconsaxPlusLinear.eye,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.md),
          if (secondary == null)
            primary
          else
            Row(
              children: [
                Expanded(child: primary),
                const SizedBox(width: BocSpace.xs),
                Expanded(child: secondary),
              ],
            ),
        ],
      ),
    );
  }
}

/// Semicircular progress toward a savings target, with start and target
/// labels. Progress comes from the server; the arc only draws it.
class BocProgressArc extends StatelessWidget {
  const BocProgressArc({
    required this.progress,
    required this.targetLabel,
    required this.color,
    super.key,
  });

  /// 0–1.
  final double progress;
  final String targetLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final value = progress.clamp(0.0, 1.0);
    final percent = (value * 100).round();
    return Semantics(
      label: '$percent percent of $targetLabel saved',
      excludeSemantics: true,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: CustomPaint(
              painter: _ArcPainter(
                progress: value,
                track: colors.successContainer,
                fill: color,
              ),
              child: Align(
                alignment: const Alignment(0, 0.7),
                child: Text('$percent%', style: theme.textTheme.displaySmall),
              ),
            ),
          ),
          const SizedBox(height: BocSpace.xs),
          Row(
            children: [
              Text('0%', style: theme.textTheme.bodySmall?.figures),
              const Spacer(),
              Text(targetLabel, style: theme.textTheme.bodySmall?.figures),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  final double progress;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 18.0;
    final radius = math.min(size.width / 2, size.height) - stroke / 2;
    final center = Offset(size.width / 2, size.height);
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint paint(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, paint(track));
    if (progress > 0) {
      canvas.drawArc(rect, math.pi, math.pi * progress, false, paint(fill));
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// Pill choices for durations, frequencies and days. Single-select by
/// default; [multiSelect] allows several (e.g. Padi contribution days).
class BocChoiceChips<T> extends StatelessWidget {
  const BocChoiceChips({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.multiSelect = false,
    super.key,
  });

  final List<({T value, String label})> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = theme.brightness == Brightness.dark
        ? BocColors.navy
        : BocColors.goldLight;
    return Wrap(
      spacing: BocSpace.xs,
      runSpacing: BocSpace.xs,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: selected.contains(option.value),
            showCheckmark: multiSelect,
            labelStyle: theme.textTheme.titleSmall?.copyWith(
              color: selected.contains(option.value) ? selectedLabel : null,
            ),
            onSelected: (isSelected) {
              if (!multiSelect) {
                onChanged({option.value});
                return;
              }
              final next = {...selected};
              isSelected ? next.add(option.value) : next.remove(option.value);
              onChanged(next);
            },
          ),
      ],
    );
  }
}

/// A frozen account's marker: lock icon and text, announced as one label.
class FrozenLabel extends StatelessWidget {
  const FrozenLabel({this.color, super.key});

  /// Defaults to the info token, which reads on themed surfaces.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.bocColors.info;
    return Semantics(
      label: 'Account frozen',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(IconsaxPlusLinear.lock, size: 14, color: tint),
          const SizedBox(width: BocSpace.xxs),
          Text(
            'Frozen',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: tint),
          ),
        ],
      ),
    );
  }
}
