part of '../app_flow/app_ui.dart';

/// Keeps forms and reading content comfortable on tablets and wide windows.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth = 840,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Fills tall viewports, but lets a Column (including Spacers) scroll on short
/// screens. Intended for small, eager onboarding/empty-state layouts only.
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}

/// Content-sized tiles: narrow windows and larger text reduce column count;
/// tile height remains driven by content rather than a fixed aspect ratio.
class ResponsiveTiles extends StatelessWidget {
  const ResponsiveTiles({
    required this.children,
    this.minTileWidth = 160,
    this.maxColumns = 4,
    this.spacing = 12,
    super.key,
  });
  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns =
          ((constraints.maxWidth + spacing) / (minTileWidth * scale + spacing))
              .floor()
              .clamp(1, maxColumns);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}
