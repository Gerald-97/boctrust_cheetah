part of '../app_flow/app_flow_navigator.dart';

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
    super.key,
  });

  final String title;

  /// Preformatted balance, or null when none has been returned yet.
  final String? balance;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final value = balance;
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

/// A savings product in the "Choose a plan" carousel.
class PlanTypeCard extends StatelessWidget {
  const PlanTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.container,
    required this.onTap,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final Color container;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Material(
        color: context.bocColors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(BocSpace.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: container,
                    borderRadius: BorderRadius.circular(BocRadius.sm),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(icon, color: accent),
                  ),
                ),
                const SizedBox(height: BocSpace.sm),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: BocSpace.xxs),
                Expanded(
                  child: Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
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
