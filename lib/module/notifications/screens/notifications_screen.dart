import 'package:flutter/material.dart';

import '../../app_flow/app_ui.dart';

/// Push delivery is not an inbox: there is no service that returns past
/// notifications, so this neither lists sample activity nor claims the inbox
/// is empty.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    return AppScaffold(
      title: 'Notifications',
      activeSection: AppSection.home,
      onBack: navigator.maybePop,
      // A tab replaces this page with the section hub.
      onSectionSelected: (section) => replaceWithSection(context, section),
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
