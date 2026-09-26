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
    const items =
        <
          ({
            AppSection section,
            IconData icon,
            IconData activeIcon,
            String label,
          })
        >[
          (
            section: AppSection.home,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
          ),
          (
            section: AppSection.save,
            icon: Icons.savings_outlined,
            activeIcon: Icons.savings_rounded,
            label: 'Save',
          ),
          (
            section: AppSection.send,
            icon: Icons.send_outlined,
            activeIcon: Icons.send_rounded,
            label: 'Send',
          ),
          (
            section: AppSection.payments,
            icon: Icons.receipt_long_outlined,
            activeIcon: Icons.receipt_long_rounded,
            label: 'Pay',
          ),
          (
            section: AppSection.account,
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Account',
          ),
        ];
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final activeColor = theme.brightness == Brightness.dark
        ? colors.textPrimary
        : BocColors.navy;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        boxShadow: const [
          BoxShadow(
            color: BocColors.navShadow,
            offset: Offset(0, -1),
            blurRadius: 2,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            BocSpace.xs,
            BocSpace.xs,
            BocSpace.xs,
            BocSpace.xs,
          ),
          child: ResponsiveContent(
            child: Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: item.section == selected,
                      label: item.label,
                      // The label replaces the inner InkWell's semantics, so
                      // the tap action has to be declared here.
                      onTap: () => onSelected(item.section),
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(BocRadius.sm),
                        onTap: () => onSelected(item.section),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: BocSpace.minTouch,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: BocSpace.xxs,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.section == selected
                                      ? item.activeIcon
                                      : item.icon,
                                  size: 24,
                                  color: item.section == selected
                                      ? activeColor
                                      : colors.textTertiary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: item.section == selected
                                        ? activeColor
                                        : colors.textTertiary,
                                    fontWeight: item.section == selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
