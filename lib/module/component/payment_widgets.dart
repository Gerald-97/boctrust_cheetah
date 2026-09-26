part of '../app_flow/app_flow_navigator.dart';

/// A payment or transfer option: tinted icon tile, title and one-line
/// description in a full-width tappable card.
class PaymentActionCard extends StatelessWidget {
  const PaymentActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: context.bocColors.surface,
      borderRadius: BorderRadius.circular(BocRadius.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BocSpace.md),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  // Navy on light tiles; light text colour on dark tiles.
                  child: Icon(
                    icon,
                    color: color.computeLuminance() < 0.3
                        ? context.bocColors.textPrimary
                        : BocColors.navy,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: BocSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.bocColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A biller category tile in the Payments grid.
class BillGridItem extends StatelessWidget {
  const BillGridItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Accent for the icon.
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 80),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: BocSpace.xxs,
                vertical: BocSpace.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: BocSpace.xs),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
