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
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: onBack == null
            ? null
            : IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
              ),
        automaticallyImplyLeading: false,
        title:
            titleWidget ??
            Text(
              title ?? '',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
        actions: actions,
      ),
      body: body,
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
    const items = <({AppSection section, IconData icon, String label})>[
      (section: AppSection.home, icon: Icons.home_outlined, label: 'Home'),
      (section: AppSection.save, icon: Icons.savings_outlined, label: 'Save'),
      (section: AppSection.send, icon: Icons.send_outlined, label: 'Send'),
      (
        section: AppSection.payments,
        icon: Icons.receipt_long_outlined,
        label: 'Pay',
      ),
      (
        section: AppSection.account,
        icon: Icons.person_outline_rounded,
        label: 'Account',
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 18),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final active = item.section == selected;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(item.section),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: active ? 6 : 0,
                        height: active ? 6 : 0,
                        margin: EdgeInsets.only(bottom: active ? 4 : 0),
                        decoration: const BoxDecoration(
                          color: BocColors.gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Icon(
                        item.icon,
                        size: 20,
                        color: active
                            ? Theme.of(context).textTheme.titleMedium?.color
                            : Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Theme.of(context).textTheme.titleMedium?.color
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
