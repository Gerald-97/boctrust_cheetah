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
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final (icon, color, container) = switch (kind) {
      BocStatusKind.success => (
        Icons.check_rounded,
        colors.success,
        colors.successContainer,
      ),
      BocStatusKind.pending => (
        IconsaxPlusLinear.clock_1,
        colors.warning,
        colors.warningContainer,
      ),
      BocStatusKind.failed => (
        Icons.close_rounded,
        colors.error,
        colors.errorContainer,
      ),
    };
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
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: container,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 64,
                            child: Icon(icon, color: color, size: 32),
                          ),
                        ),
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
