part of '../app_flow/app_ui.dart';

/// The approved Cheetah app icon. Decorative by default: give it a
/// [semanticLabel] only where no adjacent Cheetah text names it.
class BocBrandMark extends StatelessWidget {
  const BocBrandMark({required this.size, this.semanticLabel, super.key});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/branding/cheetah_app_icon.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// The app's name, Cheetah, with its "by BocTrust" tagline beside the brand
/// mark: stacked on the startup screen, in one row in the home header.
class CheetahBrand extends StatelessWidget {
  /// Stacked, for the startup, onboarding and sign-in screens; the words
  /// scale with [markSize].
  const CheetahBrand.launch({this.markSize = 72, super.key}) : _compact = false;

  /// One row, sized for an app bar title.
  const CheetahBrand.header({super.key}) : markSize = 30, _compact = true;

  final double markSize;
  final bool _compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = markSize / 72;
    // Like the BOCTRUST wordmark, the lockup ignores text scaling and only
    // shrinks when the space is too narrow.
    // The tagline sits under the name, aligned to its right edge.
    final words = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Cheetah',
          textScaler: TextScaler.noScaling,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: _compact ? 18 : 34 * ratio,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'by BocTrust',
          textScaler: TextScaler.noScaling,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: _compact ? 11 : 15 * ratio,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return Semantics(
      label: 'Cheetah by BocTrust',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: _compact
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BocBrandMark(size: markSize),
                  const SizedBox(width: 8),
                  words,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BocBrandMark(size: markSize),
                  SizedBox(height: 16 * ratio),
                  words,
                ],
              ),
      ),
    );
  }
}

class OnboardingIllustration extends StatelessWidget {
  const OnboardingIllustration({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 170,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.bocColors.goldPale.withValues(alpha: 0.55),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 30,
            child: Container(
              width: 94,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Container(
            width: 98,
            height: 68,
            decoration: BoxDecoration(
              color: BocColors.goldLight,
              borderRadius: BorderRadius.circular(34),
            ),
          ),
          Positioned(
            left: 44,
            top: 77,
            child: Container(
              width: 28,
              height: 24,
              decoration: BoxDecoration(
                color: BocColors.gold,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(radius: 2, backgroundColor: BocColors.navy),
                  SizedBox(width: 6),
                  CircleAvatar(radius: 2, backgroundColor: BocColors.navy),
                ],
              ),
            ),
          ),
          Positioned(
            top: 72,
            child: Container(
              width: 24,
              height: 7,
              decoration: BoxDecoration(
                color: BocColors.navy,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const Positioned(
            right: 55,
            top: 78,
            child: Icon(
              IconsaxPlusLinear.trend_up,
              color: BocColors.green,
              size: 22,
            ),
          ),
          Positioned(
            right: 42,
            top: 44,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: BocColors.blue,
              foregroundColor: Colors.white,
              child: Icon(icon, size: 20),
            ),
          ),
          Positioned(
            left: 77,
            bottom: 39,
            child: Container(
              width: 8,
              height: 18,
              decoration: BoxDecoration(
                color: BocColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            right: 69,
            bottom: 39,
            child: Container(
              width: 8,
              height: 18,
              decoration: BoxDecoration(
                color: BocColors.gold,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegulatoryBadge extends StatelessWidget {
  const RegulatoryBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(IconsaxPlusLinear.shield_tick, size: 14, color: BocColors.green),
          SizedBox(width: 5),
          Flexible(
            child: Text(
              'Licensed by the CBN · Deposits insured by the NDIC',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
