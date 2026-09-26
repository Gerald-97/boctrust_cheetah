part of '../app_flow/app_flow_navigator.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }
}

/// Displays an API-supplied balance.
///
/// This widget renders values only. It never parses money, derives a balance,
/// or supplies a placeholder amount — [balance] must already be formatted by
/// the screen or view model. While [loading] with no balance yet, it shows a
/// neutral placeholder rather than inventing a number.
/// The navy wallet card. Renders only the preformatted values it is given;
/// a missing balance shows as unavailable, never as a sample amount.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.label,
    required this.balance,
    required this.hidden,
    required this.onToggle,
    this.secondaryLabel,
    this.secondaryValue,
    this.statusLabel,
    this.footer,
    this.loading = false,
    super.key,
  });

  final String label;

  /// Preformatted display balance, or null when none has been returned yet.
  final String? balance;
  final bool hidden;
  final VoidCallback onToggle;
  final String? secondaryLabel;
  final String? secondaryValue;
  final String? statusLabel;
  final Widget? footer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final secondary = secondaryValue;
    final status = statusLabel;
    final footerWidget = footer;
    final value = balance;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onNavyMuted,
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 126),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BocRadius.md),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BocColors.navy, BocColors.navy2],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -48,
            bottom: -64,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: BocColors.goldLight.withValues(alpha: 0.10),
                  width: 16,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.md,
              BocSpace.md,
              BocSpace.xs,
              BocSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: muted)),
                    if (loading)
                      Padding(
                        padding: const EdgeInsets.only(right: BocSpace.xs),
                        child: SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onNavyMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Flexible(
                      child: value == null
                          ? Semantics(
                              label: '$label unavailable',
                              excludeSemantics: true,
                              child: Text(
                                '—',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: colors.onNavy,
                                ),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: BocMoneyText(
                                value,
                                hidden: hidden,
                                semanticsLabel: label,
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: colors.onNavy,
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      tooltip: hidden ? 'Show balance' : 'Hide balance',
                      onPressed: onToggle,
                      color: colors.onNavyMuted,
                      icon: Icon(
                        hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                if (status != null)
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: BocColors.goldLight,
                    ),
                  ),
                if (secondary != null) ...[
                  const SizedBox(height: BocSpace.xxs),
                  Padding(
                    padding: const EdgeInsets.only(right: BocSpace.xs),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            secondaryLabel ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onNavyMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: BocSpace.sm),
                        Flexible(
                          child: Text(
                            hidden ? '••••••' : secondary,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(color: colors.onNavy)
                                .figures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ?footerWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One of the Home quick actions: a tinted icon tile over a label, tappable
/// across the whole column.
class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BocRadius.sm),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72, minWidth: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BocSpace.xxs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(BocRadius.sm),
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(icon, color: foreground, size: 24),
                  ),
                ),
                const SizedBox(height: BocSpace.xs),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SavingsOverviewCard extends StatelessWidget {
  const SavingsOverviewCard({
    required this.category,
    required this.name,
    required this.metric,
    required this.amount,
    required this.icon,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String category;
  final String name;
  final String metric;
  final String amount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                RoundedIcon(icon: icon, color: color, size: 24),
                const SizedBox(width: 6),
                Text(
                  category.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            const Spacer(),
            Center(
              child: SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: double.tryParse(metric.replaceAll('%', '')) == null
                          ? 1
                          : (double.parse(metric.replaceAll('%', '')) / 100)
                                .clamp(0.0, 1.0),
                      strokeWidth: 5,
                      backgroundColor: Theme.of(context).dividerColor,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Text(
                      metric,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                amount,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ).figures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductTile extends StatelessWidget {
  const ProductTile({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        onTap: onTap,
        child: Row(
          children: [
            RoundedIcon(icon: icon, color: color),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 19),
          ],
        ),
      ),
    );
  }
}

class ActivePlanCard extends StatelessWidget {
  const ActivePlanCard({
    required this.metric,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String metric;
  final String name;
  final String subtitle;
  final String amount;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: metric.contains('%')
                      ? double.parse(metric.replaceAll('%', '')) / 100
                      : 1,
                  strokeWidth: 5,
                  backgroundColor: Theme.of(context).dividerColor,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Text(
                  metric,
                  style: const TextStyle(
                    fontSize: 10.5,
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
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 7),
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ).figures,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class AccountSelectorCard extends StatelessWidget {
  const AccountSelectorCard({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String label;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        children: [
          RoundedIcon(icon: icon, color: BocColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Text(
            'Change',
            style: TextStyle(
              color: BocColors.blue,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
