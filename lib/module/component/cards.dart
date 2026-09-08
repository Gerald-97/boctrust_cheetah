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

  static const _mutedText = Color(0xFFC7D3E0);

  @override
  Widget build(BuildContext context) {
    final secondary = secondaryValue;
    final status = statusLabel;
    final footerWidget = footer;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BocColors.navy, BocColors.navy2, Color(0xFF234A72)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: BocColors.goldLight.withValues(alpha: 0.18),
                  width: 14,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(color: _mutedText, fontSize: 12),
                      ),
                    ),
                    if (loading)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _mutedText,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _balanceText(context)),
                    IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: balance == null ? null : onToggle,
                      tooltip: hidden ? 'Show balance' : 'Hide balance',
                      icon: Icon(
                        hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ],
                ),
                if (status != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: const TextStyle(
                      color: BocColors.goldLight,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (secondary != null || footerWidget != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 13),
                ],
                if (secondary != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          secondaryLabel ?? '',
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          hidden ? '••••••' : secondary,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ?footerWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceText(BuildContext context) {
    final value = balance;
    final text = value == null
        ? '—'
        : hidden
        ? '••••••••••'
        : value;
    return Semantics(
      label: value == null
          ? '$label unavailable'
          : hidden
          ? '$label hidden'
          : '$label $value',
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Text(
          text,
          key: ValueKey('$text-$hidden'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}

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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: foreground, size: 22),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                ),
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
                  ),
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
