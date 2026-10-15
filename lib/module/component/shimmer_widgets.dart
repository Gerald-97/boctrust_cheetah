part of '../app_flow/app_ui.dart';

/// A theme-matched loading shape. Its animation stops when motion is disabled
/// and the parent skeleton owns the spoken loading label.
class AppShimmerBlock extends StatefulWidget {
  const AppShimmerBlock({
    required this.height,
    this.width = double.infinity,
    this.radius = BocRadius.xs,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final double width;
  final double height;
  final double radius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  State<AppShimmerBlock> createState() => _AppShimmerBlockState();
}

class _AppShimmerBlockState extends State<AppShimmerBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _sweep.stop();
    } else if (!_sweep.isAnimating) {
      _sweep.repeat();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base =
        widget.baseColor ??
        (dark
            ? colors.surfaceMuted
            : Color.lerp(colors.surface, colors.border, 0.65)!);
    final highlight =
        widget.highlightColor ??
        (dark ? Color.lerp(base, colors.textTertiary, 0.24)! : colors.surface);
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, _) {
        final position = -1.5 + _sweep.value * 3;
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(position, 0),
                end: Alignment(position + 1.5, 0),
                colors: [base, highlight, base],
                stops: const [0, 0.5, 1],
              ),
            ),
          ),
        );
      },
    );
  }
}
