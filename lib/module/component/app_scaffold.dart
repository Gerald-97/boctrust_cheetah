part of '../app_flow/app_flow_navigator.dart';

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
    return Scaffold(
      // The floating nav pill is translucent, so the page shows through it.
      extendBody: true,
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
      body: SafeArea(top: false, child: ResponsiveContent(child: body)),
      bottomNavigationBar: showBottomNavigation
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
    // Figma's text/fade in light. Dark needs the brighter tertiary to stay
    // legible on the surface; high contrast raises both to textSecondary.
    final inactiveColor = dark ? colors.textTertiary : colors.textHint;
    final pillRadius = BorderRadius.circular(BocRadius.pill);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.md + BocSpace.xxs,
          0,
          BocSpace.md + BocSpace.xxs,
          BocSpace.xs,
        ),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            // The shadow sits outside the clip so the blur doesn't cut it off.
            child: DecoratedBox(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.circular(BocRadius.pill)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33B4B4B4),
                    offset: Offset(0, 2),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: pillRadius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? colors.surface.withValues(alpha: 0.8)
                          : const Color(0xCCFFFFFF),
                      borderRadius: pillRadius,
                    ),
                    child: SizedBox(
                      height: 73,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: BocSpace.md,
                        ),
                        child: Row(
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: BocSpace.minTouch),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/svg/nav/${asset}_${selected ? 'bold' : 'linear'}.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
