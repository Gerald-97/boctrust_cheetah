part of '../../app_flow/app_flow_navigator.dart';

extension NotificationsScreen on AppFlowNavigatorState {
  /// Push delivery is not an inbox: there is no service that returns past
  /// notifications, so this neither lists sample activity nor claims the
  /// inbox is empty.
  Widget _notificationsScreen() {
    return AppScaffold(
      title: 'Notifications',
      activeSection: AppSection.home,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: const [
          ApiStateCard(
            title: 'Notification history is unavailable',
            message: 'Your notification history cannot be displayed yet.',
            tone: ApiStateTone.info,
          ),
        ],
      ),
    );
  }
}
