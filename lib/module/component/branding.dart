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
    final ratio = markSize / 72;
    // Like the BOCTRUST wordmark, the lockup ignores text scaling and only
    // shrinks when the space is too narrow.
    final words = _compact
        ? const CheetahBrandWords._header()
        : CheetahBrandWords(markSize: markSize);
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

/// The lockup's words, `Cheetah` over `by BocTrust`, sized to sit under a
/// brand mark of [markSize]. [color], when given, paints both words (navy on
/// the gold splash); otherwise they follow the theme.
class CheetahBrandWords extends StatelessWidget {
  const CheetahBrandWords({
    required this.markSize,
    this.titleOpacity = 1,
    this.bylineOpacity = 1,
    this.color,
    super.key,
  }) : _compact = false;

  /// The smaller, fixed-size words of the one-row header lockup.
  const CheetahBrandWords._header()
    : markSize = 30,
      titleOpacity = 1,
      bylineOpacity = 1,
      color = null,
      _compact = true;

  final double markSize;
  final double titleOpacity;
  final double bylineOpacity;
  final Color? color;
  final bool _compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = markSize / 72;
    // The tagline sits under the name, aligned to its right edge.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Opacity(
          opacity: titleOpacity,
          child: Text(
            'Cheetah',
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: _compact ? 18 : 34 * ratio,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Opacity(
          opacity: bylineOpacity,
          child: Text(
            'by BocTrust',
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: _compact ? 11 : 15 * ratio,
              color: color ?? theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class RegulatoryBadge extends StatelessWidget {
  const RegulatoryBadge({super.key}) : _splash = false;

  /// The same copy as a plain navy line, for the gold startup screen.
  const RegulatoryBadge.splash({super.key}) : _splash = true;

  final bool _splash;

  static const _copy = 'Licensed by the CBN · Deposits insured by the NDIC';

  @override
  Widget build(BuildContext context) {
    if (_splash) {
      return const Text(
        _copy,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: BocColors.navy,
        ),
      );
    }
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
              _copy,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
