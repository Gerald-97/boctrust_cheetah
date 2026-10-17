import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';

/// The Flutter half of the cold-launch handoff: the Cheetah mark stays where
/// the native splash drew it (120 px, centred on the full screen), settles
/// with a small pulse, then `Cheetah` and `by BocTrust` fade in beneath it.
/// Paints no background; the host supplies the gold field.
class StartupBrandSequence extends StatefulWidget {
  const StartupBrandSequence({required this.reduceMotion, super.key});

  /// Shows the final composition at once, with no animation.
  final bool reduceMotion;

  @override
  State<StartupBrandSequence> createState() => _StartupBrandSequenceState();
}

class _StartupBrandSequenceState extends State<StartupBrandSequence>
    with SingleTickerProviderStateMixin {
  static const _markSize = 120.0;
  static const _total = 2700.0;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2700),
    value: widget.reduceMotion ? 1 : 0,
  );

  late final Animation<double> _scale =
      TweenSequence([
        TweenSequenceItem(
          tween: Tween(
            begin: 1.0,
            end: 1.04,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(
            begin: 1.04,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1,
        ),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 1300 / _total),
        ),
      );

  late final Animation<double> _title = CurvedAnimation(
    parent: _controller,
    curve: const Interval(1300 / _total, 2000 / _total, curve: Curves.easeOut),
  );

  late final Animation<double> _byline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(2000 / _total, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Words start below the mark, spaced as in CheetahBrand.launch.
        final wordsTop =
            constraints.maxHeight / 2 + _markSize / 2 + 16 * _markSize / 72;
        return Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                container: true,
                label: 'Cheetah by BocTrust',
                excludeSemantics: true,
                child: Stack(
                  children: [
                    Center(
                      child: ScaleTransition(
                        scale: _scale,
                        child: const BocBrandMark(size: _markSize),
                      ),
                    ),
                    Positioned(
                      top: wordsTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => CheetahBrandWords(
                            markSize: _markSize,
                            titleOpacity: _title.value,
                            bylineOpacity: _byline.value,
                            color: BocColors.navy,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: RegulatoryBadge.splash(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
