part of '../app_flow/app_ui.dart';

/// The 40px circular back control used in every app bar, inside a 48px
/// hit area.
class BocBackButton extends StatelessWidget {
  const BocBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return Semantics(
      button: true,
      label: 'Back',
      child: InkResponse(
        onTap: onPressed,
        radius: BocSpace.minTouch / 2,
        child: SizedBox.square(
          dimension: BocSpace.minTouch,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 40,
                child: Icon(
                  IconsaxPlusLinear.arrow_left_1,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two or more mutually exclusive options on one track, such as
/// Phone number / Email or Small / Medium / Large.
class BocSegmentedControl<T> extends StatelessWidget {
  const BocSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<({T value, String label})> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final text = Theme.of(context).textTheme.titleSmall;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(BocSpace.xxs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.sm),
      ),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                button: true,
                selected: segment.value == selected,
                child: InkWell(
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                  onTap: () => onChanged(segment.value),
                  child: AnimatedContainer(
                    duration: BocMotion.fast,
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: BocSpace.xs,
                      vertical: BocSpace.xs,
                    ),
                    decoration: BoxDecoration(
                      color: segment.value == selected
                          ? BocColors.goldLight
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(BocRadius.sm),
                    ),
                    child: Text(
                      segment.label,
                      textAlign: TextAlign.center,
                      style: text?.copyWith(
                        color: segment.value == selected
                            ? BocColors.navy
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label/value tiles for a confirmation step. Two columns, or one when the
/// text is scaled up enough that two would crowd.
class BocSummaryGrid extends StatelessWidget {
  const BocSummaryGrid({required this.items, super.key});

  final List<({String label, String value})> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final columns = MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 2;
    Widget tile(({String label, String value}) item) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BocSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
      ),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.label, style: theme.textTheme.bodySmall),
            const SizedBox(height: BocSpace.xxs),
            Text(item.value, style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final slice = items.skip(i).take(columns).toList();
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < columns; j++) ...[
                if (j > 0) const SizedBox(width: BocSpace.xs),
                Expanded(
                  child: j < slice.length
                      ? tile(slice[j])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: BocSpace.xs),
          rows[i],
        ],
      ],
    );
  }
}

enum BocStatusKind { success, pending, failed }

/// A full-screen outcome. Only reachable from a server-confirmed result (or a
/// server failure); never shown to complete a flow visually.
class BocStatusScreen extends StatelessWidget {
  const BocStatusScreen({
    required this.kind,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    super.key,
  });

  final BocStatusKind kind;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryLabel = this.secondaryLabel;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          child: ScrollableFill(
            child: Padding(
              padding: const EdgeInsets.all(BocSpace.gutter),
              child: Column(
                children: [
                  const Spacer(),
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      children: [
                        BocStatusMark(kind: kind),
                        const SizedBox(height: BocSpace.lg),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: BocSpace.xs),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: BocSpace.lg),
                  PrimaryButton(label: primaryLabel, onPressed: onPrimary),
                  if (secondaryLabel != null) ...[
                    const SizedBox(height: BocSpace.xs),
                    BocTextButton(
                      label: secondaryLabel,
                      onPressed: onSecondary,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Explains that an action is not available yet. Every CTA whose capability
/// is unavailable opens this instead of silently doing nothing.
abstract final class BocUnavailableSheet {
  static Future<void> show(BuildContext context, {String? title}) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colors = sheetContext.bocColors;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            0,
            BocSpace.gutter,
            BocSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                IconsaxPlusLinear.timer,
                size: 32,
                color: colors.textTertiary,
              ),
              const SizedBox(height: BocSpace.sm),
              Text(
                title ?? 'Not available yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: BocSpace.xs),
              Text(
                "This isn't available yet. We'll switch it on in the app as "
                "soon as it's ready.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: BocSpace.lg),
              SecondaryButton(
                label: 'OK',
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A preformatted naira amount in FH Oscar, with the kobo after the last
/// decimal point at 60% size. Hidden amounts keep a masked, fixed shape.
class BocMoneyText extends StatelessWidget {
  const BocMoneyText(
    this.value, {
    this.hidden = false,
    this.style,
    this.semanticsLabel = 'Amount',
    super.key,
  });

  final String value;
  final bool hidden;

  /// Defaults to `displayMedium` (28px FH Oscar).
  final TextStyle? style;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? Theme.of(context).textTheme.displayMedium)!.figures;
    if (hidden) {
      return Semantics(
        label: '$semanticsLabel hidden',
        excludeSemantics: true,
        child: Text('₦ ••••••', style: base),
      );
    }
    final dot = value.lastIndexOf('.');
    final hasKobo = dot > 0 && dot < value.length - 1;
    return Semantics(
      label: '$semanticsLabel $value',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: hasKobo ? value.substring(0, dot + 1) : value),
            if (hasKobo)
              TextSpan(
                text: value.substring(dot + 1),
                style: TextStyle(fontSize: (base.fontSize ?? 28) * 0.6),
              ),
          ],
        ),
        style: base,
      ),
    );
  }
}

/// The outcome badge for a transaction, animated in the brand palette:
/// success pops in, draws its check and sends out gold ripples; failure
/// draws its cross and shakes once; pending turns a slow arc. With reduced
/// motion it shows the finished badge at once.
class BocStatusMark extends StatefulWidget {
  const BocStatusMark({required this.kind, this.size = 96, super.key});

  final BocStatusKind kind;
  final double size;

  @override
  State<BocStatusMark> createState() => _BocStatusMarkState();
}

class _BocStatusMarkState extends State<BocStatusMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.kind == BocStatusKind.pending ? 1400 : 1100,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.kind == BocStatusKind.pending ? 0.25 : 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      widget.kind == BocStatusKind.pending
          ? _controller.repeat()
          : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final (color, container, label) = switch (widget.kind) {
      BocStatusKind.success => (
        colors.success,
        colors.successContainer,
        'Successful',
      ),
      BocStatusKind.pending => (
        colors.warning,
        colors.warningContainer,
        'Processing',
      ),
      BocStatusKind.failed => (colors.error, colors.errorContainer, 'Failed'),
    };
    final size = widget.size;
    return Semantics(
      label: label,
      liveRegion: true,
      child: SizedBox.square(
        // Room for the ripples, which grow past the badge.
        dimension: size * 1.6,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _StatusMarkPainter(
              kind: widget.kind,
              t: _controller.value,
              size: size,
              color: color,
              container: container,
              ripple: BocColors.gold,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusMarkPainter extends CustomPainter {
  const _StatusMarkPainter({
    required this.kind,
    required this.t,
    required this.size,
    required this.color,
    required this.container,
    required this.ripple,
  });

  final BocStatusKind kind;

  /// Controller value, 0–1 (a looping turn for pending).
  final double t;
  final double size;
  final Color color;
  final Color container;
  final Color ripple;

  /// [t] mapped into the [begin, end] window, eased.
  static double _phase(double t, double begin, double end, [Curve? curve]) {
    final v = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    return (curve ?? Curves.easeOutCubic).transform(v);
  }

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final pending = kind == BocStatusKind.pending;
    var center = canvasSize.center(Offset.zero);
    final radius = size / 2;

    if (kind == BocStatusKind.failed) {
      // One decaying shake once the cross is drawn.
      final shake = _phase(t, 0.7, 1, Curves.linear);
      if (shake > 0 && shake < 1) {
        center += Offset(
          math.sin(shake * math.pi * 6) * (1 - shake) * size * 0.06,
          0,
        );
      }
    }

    if (kind == BocStatusKind.success) {
      for (final delay in const [0.45, 0.6]) {
        final p = _phase(t, delay, delay + 0.4);
        if (p <= 0 || p >= 1) continue;
        canvas.drawCircle(
          center,
          radius * (1 + p * 0.55),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.03
            ..color = ripple.withValues(alpha: 0.45 * (1 - p)),
        );
      }
    }

    final pop = pending ? 1.0 : _phase(t, 0, 0.35, Curves.easeOutBack);
    canvas.drawCircle(center, radius * pop, Paint()..color = container);
    canvas.drawCircle(center, radius * 0.66 * pop, Paint()..color = color);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size * 0.07
      ..color = Colors.white;
    final r = radius * 0.3;

    switch (kind) {
      case BocStatusKind.success:
        final check = Path()
          ..moveTo(center.dx - r, center.dy + r * 0.05)
          ..lineTo(center.dx - r * 0.25, center.dy + r * 0.75)
          ..lineTo(center.dx + r, center.dy - r * 0.6);
        _drawPartial(canvas, check, _phase(t, 0.3, 0.7), stroke);
      case BocStatusKind.failed:
        final first = Path()
          ..moveTo(center.dx - r * 0.8, center.dy - r * 0.8)
          ..lineTo(center.dx + r * 0.8, center.dy + r * 0.8);
        final second = Path()
          ..moveTo(center.dx + r * 0.8, center.dy - r * 0.8)
          ..lineTo(center.dx - r * 0.8, center.dy + r * 0.8);
        _drawPartial(canvas, first, _phase(t, 0.3, 0.5), stroke);
        _drawPartial(canvas, second, _phase(t, 0.5, 0.7), stroke);
      case BocStatusKind.pending:
        // Clock hands, with a gold arc turning round the badge.
        canvas.drawLine(center, center.translate(0, -r * 0.8), stroke);
        canvas.drawLine(center, center.translate(r * 0.55, 0), stroke);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius * 0.84),
          t * math.pi * 2,
          math.pi * 0.6,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = size * 0.05
            ..color = ripple,
        );
    }
  }

  static void _drawPartial(Canvas canvas, Path path, double p, Paint paint) {
    if (p <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * p), paint);
    }
  }

  @override
  bool shouldRepaint(_StatusMarkPainter old) =>
      old.t != t || old.kind != kind || old.color != color;
}
