part of '../../app_flow/app_flow_navigator.dart';

extension AccountScreens on AppFlowNavigatorState {
  Widget _comingSoonScreen({
    required String title,
    required IconData icon,
    required String message,
  }) {
    return AppScaffold(
      title: title,
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RoundedIcon(icon: icon, color: BocColors.gold, size: 58),
              const SizedBox(height: 16),
              Text(
                'Coming soon',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () =>
                    _showMessage('You will be notified when $title launches.'),
                icon: const Icon(Icons.notifications_none_rounded),
                label: const Text("Notify me when it's ready"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
      AppThemeMode.system => Icons.settings_brightness_outlined,
    };
    return AppScaffold(
      title: 'Account',
      activeSection: AppSection.account,
      onSectionSelected: _goSection,
      actions: [
        IconButton(
          tooltip: 'Cycle theme',
          onPressed: () =>
              ref.read(themeControllerProvider.notifier).cycleMode(),
          icon: Icon(themeIcon),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: BocColors.navy,
                  foregroundColor: BocColors.goldLight,
                  child: Text(
                    'AO',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adaeze Okonkwo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: BocColors.green,
                          size: 15,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Tier 1 · Verified',
                          style: TextStyle(
                            color: BocColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Account details'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Account tier',
                subtitle: 'Tier 1 · Upgrade to Tier 2',
                onTap: () => _go(AppScreen.tiers),
              ),
              SettingsTile(
                icon: Icons.tag_rounded,
                title: 'Account number',
                subtitle: '0142 337 705',
                trailing: const Text(
                  'Copy',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onTap: () => _showMessage('Account number copied.'),
              ),
              const SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'BOCTrust MFB',
                subtitle: 'Savings account',
              ),
            ],
          ),
          const SectionHeader(title: 'Payments'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Manage beneficiaries',
                subtitle: '3 saved',
              ),
              SettingsTile(
                icon: Icons.account_balance_outlined,
                title: 'Linked banks',
                subtitle: 'For transfers out',
              ),
            ],
          ),
          const SectionHeader(title: 'More services'),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.percent_rounded,
                title: 'Loans',
                subtitle: "Borrowing isn't available yet",
                trailing: const SmallPill(text: 'Coming soon'),
                onTap: () => _go(AppScreen.loans),
              ),
              SettingsTile(
                icon: Icons.credit_card_outlined,
                title: 'Cards',
                subtitle: "Virtual & physical cards aren't available yet",
                trailing: const SmallPill(text: 'Coming soon'),
                onTap: () => _go(AppScreen.cards),
              ),
            ],
          ),
          const SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ThemeSelector(
              value: currentThemeMode,
              onChanged: (mode) =>
                  ref.read(themeControllerProvider.notifier).selectMode(mode),
            ),
          ),
          const SectionHeader(title: 'Security'),
          const SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.face_rounded,
                title: 'Face ID login',
                subtitle: 'Use face recognition to sign in',
                trailing: DemoToggle(initialValue: true),
              ),
              SettingsTile(
                icon: Icons.fingerprint_rounded,
                title: 'Fingerprint for transfers',
                subtitle: 'Approve payments with a touch',
                trailing: DemoToggle(initialValue: true),
              ),
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Transaction PIN',
                subtitle: 'Change your 4-digit PIN',
              ),
              SettingsTile(
                icon: Icons.block_rounded,
                title: 'Freeze account',
                subtitle: 'Temporarily block all transactions',
                trailing: DemoToggle(initialValue: false),
              ),
            ],
          ),
          const SectionHeader(title: 'Support'),
          const SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Chat with support',
                subtitle: 'Average reply time: 2 minutes',
              ),
              SettingsTile(
                icon: Icons.phone_outlined,
                title: 'Call customer care',
                subtitle: '+234 906 464 1439 · 0703 973 9086',
              ),
              SettingsTile(
                icon: Icons.mail_outline_rounded,
                title: 'Email support',
                subtitle: 'info@boctrustmfb.com',
              ),
            ],
          ),
          const SectionHeader(title: 'Follow BOCTrust'),
          const SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.facebook_rounded,
                title: 'Facebook',
                subtitle: '@boctrustmfb',
              ),
              SettingsTile(
                icon: Icons.alternate_email_rounded,
                title: 'X (Twitter)',
                subtitle: '@boctrustmfb',
              ),
              SettingsTile(
                icon: Icons.business_center_outlined,
                title: 'LinkedIn',
                subtitle: 'BOCTrust Microfinance Bank',
              ),
            ],
          ),
          const SectionHeader(title: 'Legal'),
          const SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Rules for using BOCTrust',
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: RegulatoryBadge(),
          ),
        ],
      ),
    );
  }
}
