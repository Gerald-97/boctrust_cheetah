part of '../../app_flow/app_flow_navigator.dart';

extension NotificationsScreen on AppFlowNavigatorState {
  Widget _notificationsScreen() {
    return AppScaffold(
      title: 'Notifications',
      activeSection: AppSection.home,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: const [
          NotificationGroup(
            label: 'Today',
            items: [
              NotificationItem(
                icon: Icons.savings_outlined,
                title: 'Boc Flex Savings interest credited',
                subtitle: '+₦412.60 added to your balance · 12:01 AM',
                color: BocColors.green,
              ),
              NotificationItem(
                icon: Icons.shield_outlined,
                title: 'Finish Tier 2 verification',
                subtitle: 'Unlock higher transfer limits · 9:14 AM',
                color: BocColors.gold,
              ),
            ],
          ),
          NotificationGroup(
            label: 'Yesterday',
            items: [
              NotificationItem(
                icon: Icons.send_rounded,
                title: 'Transfer sent',
                subtitle: '₦35,000 to Ifeoma Nwachukwu · 4:20 PM',
                color: BocColors.blue,
              ),
              NotificationItem(
                icon: Icons.groups_outlined,
                title: 'Boctrust Group Savings reminder',
                subtitle: 'Owambe Squad contribution due 28 Jul · 8:00 AM',
                color: BocColors.purple,
              ),
            ],
          ),
          NotificationGroup(
            label: 'Earlier this week',
            items: [
              NotificationItem(
                icon: Icons.account_balance_outlined,
                title: 'Bank transfer received',
                subtitle: '₦150,000 from GTBank · Mon, 9:02 AM',
                color: BocColors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
