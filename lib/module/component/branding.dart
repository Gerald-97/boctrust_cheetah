part of '../app_flow/app_flow_navigator.dart';

/// The approved Cheetah app icon. Decorative by default: give it a
/// [semanticLabel] only where no adjacent BOCTRUST text names it.
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

class BocLogo extends StatelessWidget {
  const BocLogo({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BocBrandMark(size: height),
          SizedBox(width: height * .22),
          // The wordmark is part of the logo: it keeps its size regardless of
          // text scaling and shrinks only if the space is too narrow.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'BOCTRUST',
                textScaler: TextScaler.noScaling,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: height * .45,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
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
