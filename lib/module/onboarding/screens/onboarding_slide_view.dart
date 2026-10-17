import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';

/// One onboarding slide: animated art on paper above a white panel holding the
/// copy, progress and actions.
///
/// Stays light in a dark system theme: the GIFs carry a baked-in paper
/// background, so the view pins the light theme and uses explicit colours.
class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({
    required this.gifAsset,
    required this.stillAsset,
    required this.title,
    required this.description,
    required this.index,
    required this.slideCount,
    required this.onNext,
    required this.onLogin,
    required this.onSelect,
    super.key,
  });

  @visibleForTesting
  static const arcsKey = ValueKey('onboarding-arcs');

  final String gifAsset;
  final String stillAsset;
  final String title;
  final String description;
  final int index;
  final int slideCount;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = CheetahTheme.lightTheme;
    final text = theme.textTheme;
    return Theme(
      data: theme,
      child: Material(
        color: BocColors.paper,
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Expanded(
                child: _Illustration(
                  gifAsset: gifAsset,
                  stillAsset: stillAsset,
                  index: index,
                ),
              ),
              // Sized to its copy; on short screens or large text it stops at
              // 60% of the height and scrolls, keeping the actions reachable.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.6,
                ),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: BocColors.card,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      child: ResponsiveContent(
                        maxWidth: 560,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                          child: Column(
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontSize: 23,
                                  color: BocColors.navy,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                description,
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  color: BocColors.inkSoft,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _ProgressDots(
                                index: index,
                                count: slideCount,
                                onSelect: onSelect,
                              ),
                              const SizedBox(height: 16),
                              PrimaryButton(
                                label: index == slideCount - 1
                                    ? 'Get started'
                                    : 'Next',
                                onPressed: onNext,
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: onLogin,
                                child: const Text('I already have an account'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.gifAsset,
    required this.stillAsset,
    required this.index,
  });

  final String gifAsset;
  final String stillAsset;
  final int index;

  @override
  Widget build(BuildContext context) {
    final still = Image.asset(stillAsset, fit: BoxFit.contain);
    final art = MediaQuery.disableAnimationsOf(context)
        ? still
        : Image.asset(
            gifAsset,
            // A fresh element per slide, so returning to a slide starts over.
            key: ValueKey(index),
            fit: BoxFit.contain,
            frameBuilder: (context, child, frame, _) =>
                frame == null ? still : child,
            errorBuilder: (context, error, stackTrace) => still,
          );
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(key: OnboardingSlideView.arcsKey, painter: _Arcs()),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.biggest.shortestSide;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox.square(dimension: side, child: art),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Two thin pale-gold circles, mostly off-canvas, behind the art.
class _Arcs extends CustomPainter {
  const _Arcs();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = BocColors.goldLight.withValues(alpha: 0.45);
    final w = size.width;
    final h = size.height;
    canvas
      ..drawCircle(Offset(w * 0.22, h * 0.42), w * 0.62, paint)
      ..drawCircle(Offset(-w * 0.12, h * 1.02), w * 0.5, paint);
  }

  @override
  bool shouldRepaint(_Arcs oldDelegate) => false;
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({
    required this.index,
    required this.count,
    required this.onSelect,
  });

  final int index;
  final int count;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Semantics(
            container: true,
            button: true,
            selected: i == index,
            label: 'Slide ${i + 1} of $count',
            onTap: () => onSelect(i),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: () => onSelect(i),
              child: SizedBox.square(
                dimension: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: duration,
                    width: i == index ? 28 : 10,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index
                          ? BocColors.navy
                          : BocColors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
