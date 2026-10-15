part of '../app_flow/app_ui.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    required this.activeSection,
    required this.onSectionSelected,
    this.title,
    this.titleWidget,
    this.onBack,
    this.actions,
    this.showBottomNavigation = true,
    super.key,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget body;
  final AppSection activeSection;
  final ValueChanged<AppSection> onSectionSelected;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBottomNavigation;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    // A hub in a SectionShell sits under the shell's own pill.
    final ownsPill = showBottomNavigation && !isInSectionShell(context);
    return Scaffold(
      // Content scrolls under the floating nav pill; scrollables pad their
      // ends with [FloatingNavClearance.clearOfNav] so nothing stays hidden.
      extendBody: showBottomNavigation,
      appBar: AppBar(
        leading: onBack == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: BocSpace.xs),
                child: BocBackButton(onPressed: onBack),
              ),
        leadingWidth: onBack == null ? null : BocSpace.minTouch + BocSpace.md,
        automaticallyImplyLeading: false,
        title: titleWidget ?? Text(title ?? ''),
        actions: actions,
      ),
      body: SafeArea(
        top: false,
        bottom: !showBottomNavigation,
        child: ResponsiveContent(child: body),
      ),
      bottomNavigationBar: ownsPill
          ? AppBottomNavigation(
              selected: activeSection,
              onSelected: onSectionSelected,
            )
          : null,
    );
  }
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AppSection selected;
  final ValueChanged<AppSection> onSelected;

  /// The pill itself, for tests and for measuring what it covers.
  static const pillKey = ValueKey('app-bottom-navigation-pill');

  @override
  Widget build(BuildContext context) {
    const items = <({AppSection section, String asset, String label})>[
      (section: AppSection.home, asset: 'home', label: 'Home'),
      (section: AppSection.save, asset: 'save', label: 'Save'),
      (section: AppSection.send, asset: 'send', label: 'Send'),
      (section: AppSection.payments, asset: 'pay', label: 'Pay'),
      (section: AppSection.account, asset: 'account', label: 'Account'),
    ];
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final activeColor = dark ? colors.textPrimary : BocColors.navy;
    // textTertiary rather than Figma's lighter text/fade, which is only 3:1 on
    // the pill; high contrast raises it to textSecondary.
    final inactiveColor = colors.textTertiary;
    final pillRadius = BorderRadius.circular(BocRadius.pill);
    final edgeColor = Color.lerp(
      colors.border,
      colors.textSecondary,
      dark ? 0.35 : 0.30,
    )!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.xs,
          0,
          BocSpace.xs,
          BocSpace.xs,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            // Keep the shadows outside the clip so they frame all pill edges.
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: pillRadius,
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? const Color(0x99000000)
                        : const Color(0x380F1D2B),
                    offset: const Offset(0, 3),
                    blurRadius: 8,
                  ),
                  BoxShadow(
                    color: dark
                        ? const Color(0x55000000)
                        : const Color(0x260F1D2B),
                    offset: const Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: pillRadius,
                // The solid fill stops cards and transaction rows from
                // showing through as they scroll behind the navigation.
                child: DecoratedBox(
                  key: pillKey,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: edgeColor, width: 1.2),
                    borderRadius: pillRadius,
                  ),
                  // Ink has to paint on a Material above the fill, or the
                  // fill hides the tap ripple.
                  child: Material(
                    type: MaterialType.transparency,
                    child: SizedBox(
                      height: kNavPillHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BocSpace.md,
                        ),
                        child: Row(
                          // Each slot fills the pill's height so its whole
                          // area takes taps.
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items)
                              Expanded(
                                child: _NavPillItem(
                                  asset: item.asset,
                                  label: item.label,
                                  selected: item.section == selected,
                                  color: item.section == selected
                                      ? activeColor
                                      : inactiveColor,
                                  onTap: () => onSelected(item.section),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavPillItem extends StatelessWidget {
  const _NavPillItem({
    required this.asset,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String asset;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      // The label replaces the inner InkWell's semantics, so the tap action
      // has to be declared here.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(BocRadius.sm),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svg/nav/${asset}_${selected ? 'bold' : 'linear'}.svg',
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            ),
            const SizedBox(height: 2),
            // Five slots in a 350px pill leave little room; shrink a long
            // label at narrow widths or large text instead of truncating.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Height of the floating nav pill, excluding its margin and the safe area.
const kNavPillHeight = 73.0;

extension FloatingNavClearance on EdgeInsets {
  /// Adds the space the floating nav pill covers at the bottom of an
  /// [AppScaffold] body, so a scrollable's last item can scroll clear of it.
  ///
  /// [context] may sit above the Scaffold: the device's bottom inset is read
  /// from it, and the pill's own footprint is fixed.
  EdgeInsets clearOfNav(BuildContext context) => copyWith(
    bottom:
        bottom +
        kNavPillHeight +
        BocSpace.xs +
        MediaQuery.paddingOf(context).bottom,
  );
}
