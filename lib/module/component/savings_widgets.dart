part of '../app_flow/app_flow_navigator.dart';

class SavingsHeroCard extends StatelessWidget {
  const SavingsHeroCard({
    required this.rate,
    required this.amount,
    required this.growth,
    super.key,
  });

  final String rate;
  final String amount;
  final String growth;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.5,
          colors: [
            BocColors.gold.withValues(alpha: 0.15),
            Theme.of(context).cardColor,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: BocColors.navy,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              rate,
              style: const TextStyle(
                color: BocColors.goldLight,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            amount,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 29).figures,
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(
                IconsaxPlusLinear.trend_up,
                color: BocColors.green,
                size: 15,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  growth,
                  style: const TextStyle(
                    color: BocColors.green,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({required this.text, required this.value, super.key});
  final String text;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.bocColors.goldPale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF8A6A08),
                fontSize: 11.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  color: BocColors.navy,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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

class GoalCard extends StatelessWidget {
  const GoalCard({
    required this.progress,
    required this.name,
    required this.frequency,
    required this.amount,
    super.key,
  });

  final double progress;
  final String name;
  final String frequency;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: const AlwaysStoppedAnimation(BocColors.purple),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(
                  frequency.toUpperCase(),
                  style: const TextStyle(
                    color: BocColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)
                      .figures,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FrequencySelector extends StatelessWidget {
  const FrequencySelector({super.key});

  @override
  Widget build(BuildContext context) {
    const values = ['Daily', 'Weekly', 'Monthly'];
    return Row(
      children: List.generate(
        values.length,
        (index) => Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == values.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 1 ? BocColors.navy : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: index == 1
                    ? BocColors.navy
                    : Theme.of(context).dividerColor,
              ),
            ),
            child: Text(
              values[index],
              style: TextStyle(
                color: index == 1
                    ? BocColors.goldLight
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key});

  @override
  Widget build(BuildContext context) {
    const initials = ['AO', 'IN', 'CO', '+3'];
    return SizedBox(
      width: 122,
      height: 34,
      child: Stack(
        children: List.generate(
          initials.length,
          (index) => Positioned(
            left: index * 28,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: index == initials.length - 1
                  ? context.bocColors.goldPale
                  : BocColors.navy,
              foregroundColor: index == initials.length - 1
                  ? BocColors.gold
                  : BocColors.goldLight,
              child: Text(
                initials[index],
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MemberRow extends StatelessWidget {
  const MemberRow({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.amount,
    super.key,
  });

  final String initials;
  final String name;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: BocColors.navy,
            foregroundColor: BocColors.goldLight,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 10.5),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ).figures,
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
