part of '../app_flow/app_ui.dart';

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
/// The navy wallet card (Figma "Main Wallet"). Renders only the values it is
/// given; a missing balance shows as unavailable, never as a sample amount.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    required this.label,
    required this.balance,
    required this.hidden,
    required this.onToggle,
    this.accountNumber,
    this.bankName,
    this.onCopyAccountNumber,
    this.tier,
    this.note,
    this.statusLabel,
    this.loading = false,
    super.key,
  });

  final String label;

  /// Preformatted display balance, or null when none has been returned yet.
  final String? balance;
  final bool hidden;
  final VoidCallback onToggle;

  /// Shown after the label with a copy button, when the server supplied it.
  final String? accountNumber;

  /// The funding bank, shown after [accountNumber] when supplied.
  final String? bankName;
  final VoidCallback? onCopyAccountNumber;

  /// The customer's current KYC tier, shown as a badge.
  final int? tier;

  /// A server-supplied line under the balance, e.g. interest earned today.
  final String? note;
  final String? statusLabel;
  final bool loading;

  /// Figma frame size the decorative layer is laid out against.
  static const _designSize = Size(358, 126);

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final value = balance;
    final account = accountNumber;
    final tier = this.tier;
    final note = this.note;
    final status = statusLabel;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onNavyMuted,
    );

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 126),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: BocColors.navy,
        borderRadius: BorderRadius.circular(BocRadius.md),
      ),
      child: Stack(
        children: [
          // Decorative art from the Figma frame, scaled with the card.
          Positioned.fill(
            child: ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topLeft,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.fromSize(
                  size: _designSize,
                  child: const _WalletCardArt(),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/img/wallet_noise.png',
                  repeat: ImageRepeat.repeat,
                  filterQuality: FilterQuality.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.md,
              BocSpace.xs,
              BocSpace.xs,
              BocSpace.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text: account == null ? label : '$label - ',
                          children: [
                            if (account != null)
                              TextSpan(
                                text: account,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(
                                      color: colors.onNavy,
                                      fontWeight: FontWeight.w700,
                                    )
                                    .figures,
                              ),
                            if (account != null && bankName != null)
                              TextSpan(text: ' · $bankName'),
                          ],
                        ),
                        style: muted,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (account != null && onCopyAccountNumber != null)
                      IconButton(
                        tooltip: 'Copy account number',
                        onPressed: onCopyAccountNumber,
                        icon: SvgPicture.asset(
                          'assets/svg/copy.svg',
                          width: 20,
                          height: 20,
                        ),
                      )
                    else
                      const SizedBox(height: BocSpace.minTouch),
                    if (loading)
                      Padding(
                        padding: const EdgeInsets.only(left: BocSpace.xs),
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
                                // The visible label is read just before this.
                                semanticsLabel: 'Available',
                                style: theme.textTheme.displayMedium?.copyWith(
                                  color: colors.onNavy,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: BocSpace.xs),
                    IconButton(
                      tooltip: hidden ? 'Show balance' : 'Hide balance',
                      onPressed: onToggle,
                      icon: SvgPicture.asset(
                        hidden
                            ? 'assets/svg/eye_slash.svg'
                            : 'assets/svg/eye.svg',
                        width: 20,
                        height: 20,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: BocSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (note != null)
                              Text(
                                note,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onNavyMuted,
                                ),
                              ),
                            if (status != null)
                              Text(
                                status,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: BocColors.goldLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (tier != null) ...[
                        const SizedBox(width: BocSpace.xs),
                        // "Tier N" beside it already names the tier.
                        ExcludeSemantics(child: BocTierBadge(tier: tier)),
                        const SizedBox(width: BocSpace.xs),
                        Text(
                          'Tier $tier',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: colors.onNavyMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wave lines and the soft rounded highlight from the Figma wallet frame,
/// positioned in the frame's 358×126 coordinate space.
class _WalletCardArt extends StatelessWidget {
  const _WalletCardArt();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 239.22,
          top: 83.89,
          width: 183.367,
          height: 132.292,
          child: Center(
            child: Transform.rotate(
              angle: -167.62 * math.pi / 180,
              child: Container(
                width: 166,
                height: 99,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F4F9).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(58.5),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -192,
          top: -179,
          width: 709.933,
          height: 535.65,
          child: Center(
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(1, -1, 1)
                ..rotateZ(-6.56 * math.pi / 180),
              child: SvgPicture.asset(
                'assets/svg/wallet_waves.svg',
                width: 662.338,
                height: 464.099,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The scalloped KYC tier badge with the tier number.
class BocTierBadge extends StatelessWidget {
  const BocTierBadge({required this.tier, this.size = 24, super.key});

  final int tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (tier) {
      1 => 'assets/svg/tier_1.svg',
      2 => 'assets/svg/tier_2.svg',
      3 => 'assets/svg/tier_3.svg',
      _ => null,
    };
    return Semantics(
      label: 'Tier $tier',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: asset != null
            ? SvgPicture.asset(
                asset,
                width: size,
                height: size,
                excludeFromSemantics: true,
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svg/tier_badge.svg',
                    width: size,
                    height: size,
                  ),
                  Text(
                    '$tier',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: kFigureFontFamily,
                      fontSize: size * 0.5,
                      fontWeight: FontWeight.w600,
                      color: BocColors.blue,
                      height: 1,
                    ),
                  ),
                ],
              ),
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
      onTap: onTap,
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
