part of '../../app_flow/app_flow_navigator.dart';

extension HomeScreen on AppFlowNavigatorState {
  Widget _homeScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
      AppThemeMode.system => Icons.settings_brightness_outlined,
    };
    return AppScaffold(
      titleWidget: const BocLogo(height: 26),
      activeSection: AppSection.home,
      onSectionSelected: _goSection,
      actions: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: BocColors.navy,
          ),
          tooltip: 'Change theme',
          onPressed: () =>
              ref.read(themeControllerProvider.notifier).cycleMode(),
          icon: Icon(themeIcon, size: 18),
        ),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: BocColors.navy,
          ),
          tooltip: 'Notifications',
          onPressed: () => _go(AppScreen.notifications),
          icon: const Badge(
            smallSize: 8,
            child: Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          BalanceCard(hidden: _balanceHidden, onToggle: _toggleBalanceHidden),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _go(AppScreen.tier2),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.bocColors.goldPale,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      foregroundColor: BocColors.gold,
                      child: Icon(Icons.shield_outlined),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlock higher limits',
                            style: TextStyle(
                              color: Color(0xFF7A5F08),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Finish Tier 2 — verify NIN & add next of kin',
                            style: TextStyle(
                              color: Color(0xFF8A6A08),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Color(0xFF8A6A08)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: QuickAction(
                    icon: Icons.add_rounded,
                    label: 'Add money',
                    background: context.bocColors.goldPale,
                    foreground: BocColors.gold,
                    onTap: () => _go(AppScreen.addMoney),
                  ),
                ),
                Expanded(
                  child: QuickAction(
                    icon: Icons.send_rounded,
                    label: 'Send',
                    background: context.bocColors.bluePale,
                    foreground: BocColors.blue,
                    onTap: () => _go(AppScreen.sendHub),
                  ),
                ),
                Expanded(
                  child: QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Payments',
                    background: context.bocColors.purplePale,
                    foreground: BocColors.purple,
                    onTap: () => _go(AppScreen.payments),
                  ),
                ),
                Expanded(
                  child: QuickAction(
                    icon: Icons.track_changes_rounded,
                    label: 'New target',
                    background: context.bocColors.goldPale,
                    foreground: BocColors.gold,
                    onTap: () => _go(AppScreen.target),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Your savings',
            action: 'See all',
            onAction: () => _go(AppScreen.saveHub),
          ),
          SizedBox(
            height: 184,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                SavingsOverviewCard(
                  category: 'Flex',
                  name: 'Everyday Flex',
                  metric: '12.5%',
                  amount: '₦420,180.10',
                  icon: Icons.savings_outlined,
                  color: BocColors.gold,
                  onTap: () => _go(AppScreen.flex),
                ),
                const SizedBox(width: 12),
                SavingsOverviewCard(
                  category: 'Target',
                  name: 'Rent — Dec 2026',
                  metric: '57%',
                  amount: '₦570,000',
                  icon: Icons.track_changes_rounded,
                  color: BocColors.purple,
                  onTap: () => _go(AppScreen.target),
                ),
                const SizedBox(width: 12),
                SavingsOverviewCard(
                  category: 'Fixed',
                  name: '18-month lock',
                  metric: '35%',
                  amount: '₦300,000',
                  icon: Icons.lock_outline_rounded,
                  color: BocColors.purple,
                  onTap: () => _go(AppScreen.lock),
                ),
                const SizedBox(width: 12),
                SavingsOverviewCard(
                  category: 'Group',
                  name: 'Owambe Squad',
                  metric: '46%',
                  amount: '₦460,000',
                  icon: Icons.groups_outlined,
                  color: BocColors.green,
                  onTap: () => _go(AppScreen.group),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionHeader(title: 'Recent activity', action: 'See all'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SurfaceCard(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  TransactionTile(
                    icon: Icons.savings_outlined,
                    name: 'Boc Flex Savings daily interest',
                    date: 'Today, 12:01 AM',
                    amount: '+₦412.60',
                    incoming: true,
                  ),
                  Divider(height: 1),
                  TransactionTile(
                    icon: Icons.send_rounded,
                    name: 'Sent to Ifeoma Nwachukwu',
                    date: 'Yesterday, 4:20 PM',
                    amount: '−₦35,000.00',
                  ),
                  Divider(height: 1),
                  TransactionTile(
                    icon: Icons.south_west_rounded,
                    name: 'Bank transfer received — GTBank',
                    date: 'Mon, 9:02 AM',
                    amount: '+₦150,000.00',
                    incoming: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
