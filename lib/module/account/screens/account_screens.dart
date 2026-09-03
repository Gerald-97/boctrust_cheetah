part of '../../app_flow/app_flow_navigator.dart';

extension AccountScreens on AppFlowNavigatorState {
  Widget _routePreviewScreen() {
    final preview = _previewContentForRoute(
      appPreviewRouteForRoute(widget.initialRouteName),
    );
    final rows = preview.rows;
    return AppScaffold(
      title: preview.title,
      activeSection: preview.section,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: true,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RoundedIcon(icon: preview.icon, color: preview.color, size: 52),
                const SizedBox(height: 14),
                Text(
                  preview.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  preview.summary,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: RoundedIcon(
                      icon: rows[index].$1,
                      color: preview.color,
                      size: 38,
                    ),
                    title: Text(
                      rows[index].$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(rows[index].$3),
                  ),
                  if (index != rows.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: preview.actionLabel,
            onPressed: () => _showMessage(
              '${preview.title} is available as a UI preview. API integration is pending.',
            ),
          ),
        ],
      ),
    );
  }

  ({
    String title,
    IconData icon,
    Color color,
    AppSection section,
    String summary,
    String actionLabel,
    List<(IconData, String, String)> rows,
  })
  _previewContentForRoute(AppPreviewRoute? route) {
    switch (route) {
      case AppPreviewRoute.savingsNew:
        return (
          title: 'Create savings plan',
          icon: Icons.add_circle_outline_rounded,
          color: BocColors.gold,
          section: AppSection.save,
          summary:
              'Choose Flex, Target, Fixed Deposit, or Group Savings and preview the setup fields before the savings API is connected.',
          actionLabel: 'Preview setup',
          rows: [
            (Icons.savings_outlined, 'Flex Savings', 'Withdraw anytime'),
            (
              Icons.track_changes_rounded,
              'Target Savings',
              'Save toward a goal',
            ),
            (
              Icons.lock_outline_rounded,
              'Fixed Deposit',
              'Lock funds for higher yield',
            ),
          ],
        );
      case AppPreviewRoute.flexTopUp:
        return (
          title: 'Top up Flex Savings',
          icon: Icons.add_card_rounded,
          color: BocColors.gold,
          section: AppSection.save,
          summary:
              'Preview the top-up amount, funding source, and confirmation flow for Flex Savings.',
          actionLabel: 'Preview top up',
          rows: [
            (
              Icons.account_balance_wallet_outlined,
              'Destination',
              'Everyday Flex',
            ),
            (Icons.payments_outlined, 'Amount', '₦50,000.00'),
            (Icons.verified_user_outlined, 'Authorization', 'Transaction PIN'),
          ],
        );
      case AppPreviewRoute.flexWithdraw:
        return (
          title: 'Withdraw from Flex',
          icon: Icons.call_received_rounded,
          color: BocColors.blue,
          section: AppSection.save,
          summary:
              'Preview withdrawal details for moving money from Flex Savings to your wallet.',
          actionLabel: 'Preview withdrawal',
          rows: [
            (Icons.savings_outlined, 'Source', 'Everyday Flex'),
            (
              Icons.account_balance_wallet_outlined,
              'Destination',
              'Cheetah wallet',
            ),
            (Icons.schedule_rounded, 'Delivery', 'Instant preview'),
          ],
        );
      case AppPreviewRoute.flexStatement:
        return (
          title: 'Flex statement',
          icon: Icons.receipt_long_outlined,
          color: BocColors.green,
          section: AppSection.save,
          summary:
              'Preview interest, deposits, and withdrawals for the selected Flex Savings account.',
          actionLabel: 'Preview statement export',
          rows: [
            (Icons.trending_up_rounded, 'Daily interest', '+₦412.60'),
            (Icons.add_rounded, 'Top up', '+₦50,000.00'),
            (Icons.call_received_rounded, 'Withdrawal', '-₦20,000.00'),
          ],
        );
      case AppPreviewRoute.flexSettings:
        return (
          title: 'Flex settings',
          icon: Icons.tune_rounded,
          color: BocColors.purple,
          section: AppSection.save,
          summary:
              'Preview account preferences such as auto-save rules, withdrawal destination, and statement notifications.',
          actionLabel: 'Preview settings',
          rows: [
            (Icons.autorenew_rounded, 'Auto-save', 'Weekly, ₦10,000'),
            (Icons.notifications_none_rounded, 'Interest alerts', 'Enabled'),
            (
              Icons.account_balance_outlined,
              'Withdrawal account',
              'Primary wallet',
            ),
          ],
        );
      case AppPreviewRoute.targetCreate:
        return (
          title: 'Create target',
          icon: Icons.track_changes_rounded,
          color: BocColors.blue,
          section: AppSection.save,
          summary:
              'Preview the target goal form, frequency selector, and auto-save confirmation.',
          actionLabel: 'Preview target creation',
          rows: [
            (Icons.flag_outlined, 'Goal name', 'Rent - Dec 2026'),
            (Icons.payments_outlined, 'Target amount', '₦1,000,000'),
            (Icons.calendar_month_outlined, 'Frequency', 'Weekly'),
          ],
        );
      case AppPreviewRoute.targetSort:
        return (
          title: 'Sort targets',
          icon: Icons.sort_rounded,
          color: BocColors.blue,
          section: AppSection.save,
          summary:
              'Preview sorting target savings by progress, date created, maturity date, or amount.',
          actionLabel: 'Preview sort',
          rows: [
            (Icons.trending_up_rounded, 'Progress', 'Highest first'),
            (Icons.event_available_outlined, 'Maturity', 'Soonest first'),
            (Icons.payments_outlined, 'Amount', 'Largest target first'),
          ],
        );
      case AppPreviewRoute.lockCreate:
        return (
          title: 'Create fixed deposit',
          icon: Icons.lock_outline_rounded,
          color: BocColors.purple,
          section: AppSection.save,
          summary:
              'Preview the fixed deposit setup for amount, tenor, rate, and payout account.',
          actionLabel: 'Preview lock setup',
          rows: [
            (Icons.payments_outlined, 'Amount', '₦300,000.00'),
            (Icons.timelapse_rounded, 'Tenor', '6 months'),
            (Icons.percent_rounded, 'Rate', '18% p.a.'),
          ],
        );
      case AppPreviewRoute.lockDetails:
        return (
          title: 'Fixed deposit details',
          icon: Icons.lock_clock_rounded,
          color: BocColors.purple,
          section: AppSection.save,
          summary:
              'Preview maturity date, accrued interest, payout destination, and early-break terms.',
          actionLabel: 'Preview details',
          rows: [
            (Icons.event_available_outlined, 'Maturity', '14 Oct 2026'),
            (Icons.trending_up_rounded, 'Expected interest', '₦45,000'),
            (Icons.warning_amber_rounded, 'Early exit', 'Interest forfeited'),
          ],
        );
      case AppPreviewRoute.lockAddMoney:
        return (
          title: 'Add to fixed deposit',
          icon: Icons.add_box_outlined,
          color: BocColors.purple,
          section: AppSection.save,
          summary:
              'Preview increasing an existing fixed deposit before maturity.',
          actionLabel: 'Preview add money',
          rows: [
            (Icons.lock_outline_rounded, 'Active lock', '18-month lock'),
            (Icons.payments_outlined, 'Additional amount', '₦50,000.00'),
            (Icons.percent_rounded, 'Current rate', '18% p.a.'),
          ],
        );
      case AppPreviewRoute.groupCreate:
      case AppPreviewRoute.groupContribute:
      case AppPreviewRoute.groupInvite:
      case AppPreviewRoute.groupMembers:
        return (
          title: 'Group Savings',
          icon: Icons.groups_outlined,
          color: BocColors.green,
          section: AppSection.save,
          summary:
              'Preview group setup, contributions, invites, and member status before group savings endpoints are available.',
          actionLabel: 'Preview group action',
          rows: [
            (Icons.group_add_outlined, 'Members', '6 active members'),
            (Icons.payments_outlined, 'Contribution', '₦20,000 weekly'),
            (Icons.link_rounded, 'Invite', 'Shareable invite preview'),
          ],
        );
      case AppPreviewRoute.bankTransferFunding:
        return (
          title: 'Bank transfer funding',
          icon: Icons.account_balance_outlined,
          color: BocColors.blue,
          section: AppSection.payments,
          summary:
              'Preview virtual account funding instructions and reference details.',
          actionLabel: 'Preview bank transfer',
          rows: [
            (Icons.account_balance_outlined, 'Bank', 'Cheetah MFB'),
            (Icons.numbers_rounded, 'Account number', '0198 220 341'),
            (Icons.person_outline_rounded, 'Account name', 'Adaeze Okonkwo'),
          ],
        );
      case AppPreviewRoute.cardFunding:
        return (
          title: 'Card funding',
          icon: Icons.credit_card_outlined,
          color: BocColors.gold,
          section: AppSection.payments,
          summary:
              'Preview adding money with a debit card while card processor integration is pending.',
          actionLabel: 'Preview card funding',
          rows: [
            (Icons.credit_card_outlined, 'Card', 'Visa ending 4242'),
            (Icons.payments_outlined, 'Amount', '₦50,000.00'),
            (Icons.lock_outline_rounded, 'Security', '3DS authorization'),
          ],
        );
      case AppPreviewRoute.accountBeneficiaries:
        return (
          title: 'Beneficiaries',
          icon: Icons.people_alt_outlined,
          color: BocColors.blue,
          section: AppSection.account,
          summary:
              'Preview saved Cheetah and bank beneficiaries before beneficiary APIs are connected.',
          actionLabel: 'Preview beneficiary setup',
          rows: [
            (
              Icons.person_outline_rounded,
              'Ifeoma Nwachukwu',
              'Cheetah - 0198 220 341',
            ),
            (
              Icons.account_balance_outlined,
              'Chuka Obi',
              'GTBank - 0123456789',
            ),
            (Icons.add_rounded, 'Add beneficiary', 'Local UI preview'),
          ],
        );
      case AppPreviewRoute.accountLinkedBanks:
        return (
          title: 'Linked banks',
          icon: Icons.account_balance_outlined,
          color: BocColors.green,
          section: AppSection.account,
          summary:
              'Preview connected bank accounts for withdrawals and funding.',
          actionLabel: 'Preview linked banks',
          rows: [
            (Icons.account_balance_outlined, 'GTBank', '0123456789'),
            (Icons.account_balance_outlined, 'Access Bank', '0987654321'),
            (Icons.add_rounded, 'Link another bank', 'Secure setup preview'),
          ],
        );
      case AppPreviewRoute.accountSecurity:
        return (
          title: 'Security settings',
          icon: Icons.security_rounded,
          color: BocColors.purple,
          section: AppSection.account,
          summary:
              'Preview security controls that are not yet fully represented by the current API.',
          actionLabel: 'Preview security options',
          rows: [
            (Icons.password_rounded, 'Password', 'Change password'),
            (Icons.pin_outlined, 'Transaction PIN', 'Change or recover PIN'),
            (Icons.face_rounded, 'Biometric login', 'Unavailable in API'),
          ],
        );
      case AppPreviewRoute.accountSupport:
      case AppPreviewRoute.supportChat:
      case AppPreviewRoute.supportCall:
      case AppPreviewRoute.supportEmail:
        return (
          title: 'Support',
          icon: Icons.support_agent_rounded,
          color: BocColors.gold,
          section: AppSection.account,
          summary: 'Preview customer support channels and escalation details.',
          actionLabel: 'Preview support contact',
          rows: [
            (
              Icons.chat_bubble_outline_rounded,
              'Chat',
              'Average reply: 2 minutes',
            ),
            (Icons.phone_outlined, 'Call', '+234 906 464 1439'),
            (Icons.mail_outline_rounded, 'Email', 'info@cheetahmfb.com'),
          ],
        );
      case AppPreviewRoute.privacyPolicy:
        return (
          title: 'Privacy Policy',
          icon: Icons.privacy_tip_outlined,
          color: BocColors.blue,
          section: AppSection.account,
          summary:
              'Preview the policy page structure for data collection, usage, protection, and consent.',
          actionLabel: 'Preview policy acknowledgement',
          rows: [
            (
              Icons.dataset_outlined,
              'Data collected',
              'Identity and account data',
            ),
            (
              Icons.shield_outlined,
              'Protection',
              'Encryption and access controls',
            ),
            (
              Icons.manage_accounts_outlined,
              'Your rights',
              'Access, correction, deletion',
            ),
          ],
        );
      case AppPreviewRoute.terms:
        return (
          title: 'Terms & Conditions',
          icon: Icons.description_outlined,
          color: BocColors.blue,
          section: AppSection.account,
          summary:
              'Preview the terms page structure for account usage, payments, savings, and limitations.',
          actionLabel: 'Preview terms acknowledgement',
          rows: [
            (
              Icons.account_circle_outlined,
              'Account use',
              'Customer responsibilities',
            ),
            (Icons.payments_outlined, 'Transactions', 'Limits and reversals'),
            (Icons.savings_outlined, 'Savings', 'Interest and maturity terms'),
          ],
        );
      case AppPreviewRoute.socialFacebook:
      case AppPreviewRoute.socialX:
      case AppPreviewRoute.socialLinkedIn:
        return (
          title: 'Social links',
          icon: Icons.public_rounded,
          color: BocColors.green,
          section: AppSection.account,
          summary:
              'Preview outbound social profiles without launching an external app.',
          actionLabel: 'Preview social link',
          rows: [
            (Icons.facebook_rounded, 'Facebook', '@cheetahmfb'),
            (Icons.alternate_email_rounded, 'X', '@cheetahmfb'),
            (Icons.business_center_outlined, 'LinkedIn', 'Cheetah MFB'),
          ],
        );
      case AppPreviewRoute.themeSettings:
        return (
          title: 'Theme settings',
          icon: Icons.palette_outlined,
          color: BocColors.purple,
          section: AppSection.account,
          summary:
              'Preview appearance preferences and switch between system, light, and dark themes from Account.',
          actionLabel: 'Cycle theme',
          rows: [
            (Icons.settings_brightness_outlined, 'System', 'Follow device'),
            (Icons.light_mode_outlined, 'Light', 'Bright interface'),
            (Icons.dark_mode_outlined, 'Dark', 'Low-light interface'),
          ],
        );
      case AppPreviewRoute.transactionHistory:
        return (
          title: 'Transactions',
          icon: Icons.receipt_long_outlined,
          color: BocColors.green,
          section: AppSection.payments,
          summary:
              'Preview transaction history filters and receipt access while the transaction API is pending.',
          actionLabel: 'Preview receipt',
          rows: [
            (Icons.phone_android_rounded, 'MTN Airtime', '-₦2,000.00'),
            (Icons.bolt_outlined, 'EKEDC', '-₦15,000.00'),
            (Icons.send_rounded, 'Sent to Ifeoma', '-₦35,000.00'),
          ],
        );
      case AppPreviewRoute.paymentWebView:
        return (
          title: 'Payment webview',
          icon: Icons.web_asset_outlined,
          color: BocColors.gold,
          section: AppSection.payments,
          summary:
              'Preview the hosted payment handoff screen and return states before the provider webview is connected.',
          actionLabel: 'Preview return to app',
          rows: [
            (
              Icons.open_in_browser_rounded,
              'Provider page',
              'Secure checkout preview',
            ),
            (Icons.lock_outline_rounded, 'Authorization', '3DS or OTP'),
            (
              Icons.check_circle_outline_rounded,
              'Return state',
              'Success, failed, cancelled',
            ),
          ],
        );
      case null:
        return (
          title: 'UI preview',
          icon: Icons.preview_outlined,
          color: BocColors.gold,
          section: AppSection.home,
          summary:
              'This page is available as a local UI preview while backend integration is pending.',
          actionLabel: 'Preview action',
          rows: [
            (
              Icons.visibility_outlined,
              'Visible route',
              widget.initialRouteName ?? 'Unknown route',
            ),
            (Icons.api_outlined, 'API status', 'Integration pending'),
            (
              Icons.check_circle_outline_rounded,
              'UI status',
              'Ready for review',
            ),
          ],
        );
    }
  }

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

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final result = words.map((word) => word[0].toUpperCase()).join();
    return result.isEmpty ? 'BC' : result;
  }

  /// Read-only mirror of the dedicated virtual account already loaded by Home.
  ///
  /// Copying the number stays on Home, where the full account details are
  /// shown; this tile only reports status.
  Widget _virtualAccountTile(DedicatedVirtualAccountData? account) {
    final (subtitle, pill) = switch (account?.status) {
      DedicatedVirtualAccountStatus.available => (
        account?.bankName == null
            ? 'Ready for bank transfers'
            : 'Ready · ${account!.bankName}',
        SmallPill.success('Active'),
      ),
      DedicatedVirtualAccountStatus.pending => (
        'Being set up for bank transfers',
        SmallPill.pending('Pending'),
      ),
      DedicatedVirtualAccountStatus.failed => (
        account?.failureReason ?? 'Setup did not complete',
        SmallPill.failed('Failed'),
      ),
      DedicatedVirtualAccountStatus.notRequested => (
        'Not set up for your profile yet',
        SmallPill.unavailable('Not set up'),
      ),
      DedicatedVirtualAccountStatus.unknown => (
        'Status could not be confirmed',
        SmallPill.unavailable('Unknown'),
      ),
      null => ('Open Home to load your funding details', null),
    };

    return SettingsTile(
      icon: Icons.account_balance_outlined,
      title: 'Dedicated virtual account',
      subtitle: subtitle,
      trailing: pill,
    );
  }

  Widget _accountScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.data;
    final session = ref.watch(authSessionProvider);
    // Read-only: Account reflects whatever Home already loaded and never
    // starts its own Home request.
    final virtualAccount = ref
        .watch(userHomeProvider)
        .data
        ?.dedicatedVirtualAccount;
    if (profileState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
      AppThemeMode.system => Icons.settings_brightness_outlined,
    };
    final displayName = profile?.displayName ?? 'Cheetah customer';
    final identifier =
        profile?.email ??
        profile?.phoneNumber ??
        session?.email ??
        session?.phoneNumber ??
        'Not available';
    final verified = profile?.isVerifiedAccount == true;

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
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (profileState.isError)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: MaterialBanner(
                  content: Text(
                    profileState.message ?? 'Unable to load your profile.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ref.read(userProfileProvider.notifier).load(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: BocColors.navy,
                    foregroundColor: BocColors.goldLight,
                    backgroundImage: profile?.imageUrl == null
                        ? null
                        : NetworkImage(profile!.imageUrl!),
                    child: profile?.imageUrl == null
                        ? Text(
                            _initials(displayName),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              verified
                                  ? Icons.verified_user_outlined
                                  : Icons.info_outline_rounded,
                              color: verified
                                  ? BocColors.green
                                  : BocColors.gold,
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tier ${profile?.tier ?? '—'} · '
                              '${verified ? 'Verified' : 'Verification pending'}',
                              style: TextStyle(
                                color: verified
                                    ? BocColors.green
                                    : BocColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (profileState.isLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
                  subtitle: 'Tier ${profile?.tier ?? '—'} · View limits',
                  onTap: () => _go(AppScreen.tiers),
                ),
                SettingsTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Registered identifier',
                  subtitle: identifier,
                ),
                if (profile?.email != null)
                  SettingsTile(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Email verification',
                    subtitle: profile!.isVerifiedEmail
                        ? 'Verified'
                        : 'Verify ${profile.email}',
                    trailing: profile.isVerifiedEmail
                        ? const SmallPill(text: 'Verified')
                        : null,
                    onTap: profile.isVerifiedEmail
                        ? null
                        : () => _showIdentifierVerificationSheet(
                            phone: false,
                            initialIdentifier: profile.email,
                          ),
                  ),
                if (profile?.phoneNumber != null)
                  SettingsTile(
                    icon: Icons.phone_android_rounded,
                    title: 'Phone verification',
                    subtitle: profile!.isVerifiedPhoneNumber
                        ? 'Verified'
                        : 'Verify ${profile.phoneNumber}',
                    trailing: profile.isVerifiedPhoneNumber
                        ? const SmallPill(text: 'Verified')
                        : null,
                    onTap: profile.isVerifiedPhoneNumber
                        ? null
                        : () => _showIdentifierVerificationSheet(
                            phone: true,
                            initialIdentifier: profile.phoneNumber,
                          ),
                  ),
              ],
            ),
            const SectionHeader(title: 'Wallet'),
            SettingsGroup(children: [_virtualAccountTile(virtualAccount)]),
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
              child: ThemeSelector(
                value: currentThemeMode,
                onChanged: (mode) =>
                    ref.read(themeControllerProvider.notifier).selectMode(mode),
              ),
            ),
            const SectionHeader(title: 'Security'),
            SettingsGroup(
              children: [
                SettingsTile(
                  icon: Icons.password_rounded,
                  title: 'Password',
                  subtitle: 'Change your account password',
                  onTap: _showChangePasswordDialog,
                ),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Transaction PIN',
                  subtitle: profile?.isCreatedPin == true
                      ? 'Change your 4-digit PIN'
                      : 'Create your 4-digit PIN',
                  onTap: profile?.isCreatedPin == true
                      ? _showChangePinDialog
                      : () => _openAuthDestination(
                          AuthDestination.createFirstPin,
                        ),
                ),
                SettingsTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Forgot transaction PIN',
                  subtitle: 'Verify your account and choose a new PIN',
                  onTap: _showPinRecoverySheet,
                ),
                SettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Security checks',
                  subtitle: 'Verify your current password or PIN',
                  onTap: _showSecurityCheckChooser,
                ),
                SettingsTile(
                  icon: Icons.face_rounded,
                  title: 'Biometric login',
                  subtitle: 'Not supported by the current API',
                  trailing: const SmallPill(text: 'Unavailable'),
                  onTap: () => _showMessage(
                    'Biometric login is unavailable in this API release.',
                  ),
                ),
                SettingsTile(
                  icon: Icons.block_rounded,
                  title: 'Freeze account',
                  subtitle: 'Not supported by the current API',
                  trailing: const SmallPill(text: 'Unavailable'),
                  onTap: () => _showMessage(
                    'Account freezing is unavailable in this API release.',
                  ),
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
                  subtitle: 'Rules for using Cheetah',
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: OutlinedButton.icon(
                onPressed: ref.watch(logoutProvider).isLoading
                    ? null
                    : _confirmSignOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  ref.watch(logoutProvider).isLoading
                      ? 'Signing out…'
                      : 'Sign out',
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: RegulatoryBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    _currentSecretController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    final formKey = GlobalKey<FormState>();
    var autovalidateMode = AutovalidateMode.disabled;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppPasswordField(
                    label: 'Current password',
                    controller: _currentSecretController,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                    autovalidateMode: autovalidateMode,
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    label: 'New password',
                    controller: _passwordController,
                    validator: validators.isPasswordValid,
                    autovalidateMode: autovalidateMode,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    label: 'Confirm new password',
                    controller: _confirmPasswordController,
                    validator: (value) => validators.confirmPassword(
                      value,
                      _passwordController.text,
                    ),
                    autovalidateMode: autovalidateMode,
                    autofillHints: const [AutofillHints.newPassword],
                  ),
                  const SizedBox(height: 12),
                  PasswordStrengthWidget(password: _passwordController.text),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) {
                  setDialogState(() {
                    autovalidateMode = AutovalidateMode.onUserInteraction;
                  });
                  return;
                }
                await ref
                    .read(changePasswordProvider.notifier)
                    .submit(
                      currentPassword: _currentSecretController.text,
                      newPassword: _passwordController.text,
                    );
                final result = ref.read(changePasswordProvider);
                if (!mounted || !dialogContext.mounted) return;
                if (result.isDone) Navigator.pop(dialogContext);
                if (result.isDone) {
                  _showSuccessMessage(result.message ?? 'Password updated.');
                } else {
                  _showErrorMessage(
                    result.message ?? 'Password update failed.',
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    _currentSecretController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  Future<void> _showChangePinDialog() async {
    _currentSecretController.clear();
    _pinController.clear();
    _confirmPinController.clear();
    final formKey = GlobalKey<FormState>();
    var autovalidateMode = AutovalidateMode.disabled;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change transaction PIN'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PinSecurityWarningBox(),
                  const SizedBox(height: 12),
                  const Text('Current PIN'),
                  const SizedBox(height: 8),
                  PinInputField(
                    pinLength: 4,
                    pinCtrl: _currentSecretController,
                    obscureText: true,
                    validator: validators.transactionPin,
                    autovalidateMode: autovalidateMode,
                  ),
                  const SizedBox(height: 12),
                  const Text('New PIN'),
                  const SizedBox(height: 8),
                  PinInputField(
                    pinLength: 4,
                    pinCtrl: _pinController,
                    obscureText: true,
                    validator: validators.strongTransactionPin,
                    autovalidateMode: autovalidateMode,
                  ),
                  const SizedBox(height: 12),
                  const Text('Confirm new PIN'),
                  const SizedBox(height: 8),
                  PinInputField(
                    pinLength: 4,
                    pinCtrl: _confirmPinController,
                    obscureText: true,
                    validator: (value) => value == _pinController.text
                        ? null
                        : 'PINs do not match',
                    autovalidateMode: autovalidateMode,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState?.validate() != true) {
                  setDialogState(() {
                    autovalidateMode = AutovalidateMode.onUserInteraction;
                  });
                  return;
                }
                await ref
                    .read(changePinProvider.notifier)
                    .submit(
                      currentPin: _currentSecretController.text,
                      newPin: _pinController.text,
                    );
                final result = ref.read(changePinProvider);
                if (!mounted || !dialogContext.mounted) return;
                if (result.isDone) Navigator.pop(dialogContext);
                if (result.isDone) {
                  _showSuccessMessage(
                    result.message ?? 'Transaction PIN updated.',
                  );
                } else {
                  _showErrorMessage(
                    result.message ?? 'Transaction PIN update failed.',
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
    _currentSecretController.clear();
    _pinController.clear();
    _confirmPinController.clear();
  }

  Future<void> _showIdentifierVerificationSheet({
    required bool phone,
    String? initialIdentifier,
  }) async {
    ref.invalidate(identifierVerificationProvider);
    _identifierController.text = initialIdentifier ?? '';
    _otpController.clear();
    var channel = PhoneVerificationChannel.sms;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Consumer(
          builder: (context, modalRef, _) {
            final state = modalRef.watch(identifierVerificationProvider);
            final awaitingOtp =
                state.data?.stage == IdentifierVerificationStage.awaitingOtp;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                22,
                24,
                22 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      awaitingOtp
                          ? 'Enter verification code'
                          : 'Verify ${phone ? 'phone number' : 'email'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      awaitingOtp
                          ? 'Enter the 6-digit code sent to ${state.data?.identifier}.'
                          : 'Cheetah will send a one-time verification code.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    if (awaitingOtp) ...[
                      PinInputField(
                        pinCtrl: _otpController,
                        isActive: !state.isLoading,
                      ),
                      const SizedBox(height: 10),
                      OtpExpiryLabel(expiresAt: state.data?.otpExpiresAt),
                      const SizedBox(height: 10),
                      TestOtpBanner(
                        flow: TestOtpFlow.identifierVerification,
                        controller: _otpController,
                      ),
                    ] else ...[
                      AppTextField(
                        label: phone ? 'Phone number' : 'Email address',
                        controller: _identifierController,
                        keyboardType: phone
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                      ),
                      if (phone) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PhoneVerificationChannel>(
                          initialValue: channel,
                          decoration: const InputDecoration(
                            labelText: 'Delivery channel',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: PhoneVerificationChannel.sms,
                              child: Text('SMS'),
                            ),
                            DropdownMenuItem(
                              value: PhoneVerificationChannel.whatsapp,
                              child: Text('WhatsApp'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setSheetState(() => channel = value);
                            }
                          },
                        ),
                      ],
                    ],
                    if (state.isError) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.message ?? 'Verification failed.',
                        style: const TextStyle(color: BocColors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: state.isLoading
                          ? 'Please wait…'
                          : awaitingOtp
                          ? 'Verify code'
                          : 'Send code',
                      onPressed: () async {
                        if (state.isLoading) return;
                        final notifier = modalRef.read(
                          identifierVerificationProvider.notifier,
                        );
                        if (awaitingOtp) {
                          if (validators.otp(_otpController.text) != null) {
                            _showMessage('Enter the 6-digit code.');
                            return;
                          }
                          await notifier.verify(_otpController.text);
                          final result = modalRef.read(
                            identifierVerificationProvider,
                          );
                          if (result.data?.stage ==
                                  IdentifierVerificationStage.completed &&
                              sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            await ref.read(userProfileProvider.notifier).load();
                            if (mounted) {
                              _showSuccessMessage(
                                result.message ?? 'Identifier verified.',
                              );
                            }
                          }
                          return;
                        }
                        final identifier = _identifierController.text.trim();
                        if (phone) {
                          if (!RegExp(
                            r'^\+234\d{10}$',
                          ).hasMatch(normalizeNigerianPhone(identifier))) {
                            _showMessage(
                              'Enter a valid Nigerian phone number.',
                            );
                            return;
                          }
                          await notifier.initiatePhone(identifier, channel);
                        } else {
                          if (!validators.isEmail(identifier)) {
                            _showMessage('Enter a valid email address.');
                            return;
                          }
                          await notifier.initiateEmail(identifier);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    _identifierController.clear();
    _otpController.clear();
    ref.invalidate(identifierVerificationProvider);
  }

  Future<void> _showPinRecoverySheet() async {
    ref.invalidate(pinRecoveryProvider);
    final session = ref.read(authSessionProvider);
    _identifierController.text = session?.email ?? session?.phoneNumber ?? '';
    _otpController.clear();
    _pinController.clear();
    _confirmPinController.clear();
    var channel = PhoneVerificationChannel.sms;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Consumer(
          builder: (context, modalRef, _) {
            final state = modalRef.watch(pinRecoveryProvider);
            final stage = state.data?.stage ?? RecoveryFlowStage.idle;
            final awaitingOtp = stage == RecoveryFlowStage.awaitingOtp;
            final awaitingPin = stage == RecoveryFlowStage.awaitingNewSecret;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                22,
                24,
                22 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      awaitingOtp
                          ? 'Verify your account'
                          : awaitingPin
                          ? 'Choose a new PIN'
                          : 'Reset transaction PIN',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    if (awaitingOtp) ...[
                      PinInputField(
                        pinCtrl: _otpController,
                        isActive: !state.isLoading,
                      ),
                      const SizedBox(height: 10),
                      OtpExpiryLabel(expiresAt: state.data?.otpExpiresAt),
                      const SizedBox(height: 10),
                      TestOtpBanner(
                        flow: TestOtpFlow.pinRecovery,
                        controller: _otpController,
                      ),
                    ] else if (awaitingPin) ...[
                      const PinSecurityWarningBox(),
                      const SizedBox(height: 14),
                      PinInputField(
                        pinLength: 4,
                        pinCtrl: _pinController,
                        obscureText: true,
                        isActive: !state.isLoading,
                        validator: validators.strongTransactionPin,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                      const SizedBox(height: 14),
                      PinInputField(
                        pinLength: 4,
                        pinCtrl: _confirmPinController,
                        obscureText: true,
                        isActive: !state.isLoading,
                        validator: (value) => value == _pinController.text
                            ? null
                            : 'PINs do not match',
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                      ),
                    ] else ...[
                      AppTextField(
                        label: 'Email or phone number',
                        controller: _identifierController,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PhoneVerificationChannel>(
                        initialValue: channel,
                        decoration: const InputDecoration(
                          labelText: 'Phone delivery channel',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PhoneVerificationChannel.sms,
                            child: Text('SMS'),
                          ),
                          DropdownMenuItem(
                            value: PhoneVerificationChannel.whatsapp,
                            child: Text('WhatsApp'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => channel = value);
                          }
                        },
                      ),
                    ],
                    if (state.isError) ...[
                      const SizedBox(height: 12),
                      Text(
                        state.message ?? 'PIN recovery failed.',
                        style: const TextStyle(color: BocColors.red),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: state.isLoading
                          ? 'Please wait…'
                          : awaitingOtp
                          ? 'Verify code'
                          : awaitingPin
                          ? 'Reset PIN'
                          : 'Send code',
                      onPressed: () async {
                        if (state.isLoading) return;
                        final notifier = modalRef.read(
                          pinRecoveryProvider.notifier,
                        );
                        if (awaitingOtp) {
                          if (validators.otp(_otpController.text) != null) {
                            _showMessage('Enter the 6-digit code.');
                            return;
                          }
                          await notifier.verifyOtp(_otpController.text);
                          return;
                        }
                        if (awaitingPin) {
                          if (validators.strongTransactionPin(
                                _pinController.text,
                              ) !=
                              null) {
                            _showMessage('Choose a PIN that is hard to guess.');
                            return;
                          }
                          if (_confirmPinController.text !=
                              _pinController.text) {
                            _showMessage('PINs do not match.');
                            return;
                          }
                          await notifier.reset(_pinController.text);
                          final result = modalRef.read(pinRecoveryProvider);
                          if (result.data?.stage ==
                                  RecoveryFlowStage.completed &&
                              sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                            if (mounted) {
                              _showSuccessMessage(
                                result.message ?? 'Transaction PIN reset.',
                              );
                            }
                          }
                          return;
                        }
                        final identifier = _identifierController.text.trim();
                        if (identifier.isEmpty) {
                          _showMessage('Enter your email or phone number.');
                          return;
                        }
                        await notifier.start(
                          identifier,
                          channel: identifier.contains('@') ? null : channel,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    ref.read(pinRecoveryProvider.notifier).cancel();
    _identifierController.clear();
    _otpController.clear();
    _pinController.clear();
    _confirmPinController.clear();
  }

  Future<void> _showSecurityCheckChooser() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Verify current password'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCurrentSecretVerificationDialog(pin: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pin_outlined),
              title: const Text('Verify current PIN'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCurrentSecretVerificationDialog(pin: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCurrentSecretVerificationDialog({required bool pin}) async {
    _currentSecretController.clear();
    if (pin) {
      ref.invalidate(verifyCurrentPinProvider);
    } else {
      ref.invalidate(verifyCurrentPasswordProvider);
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Verify current ${pin ? 'PIN' : 'password'}'),
        content: pin
            ? AppTextField(
                label: 'Current PIN',
                controller: _currentSecretController,
                obscureText: true,
                keyboardType: TextInputType.number,
              )
            : AppPasswordField(
                label: 'Current password',
                controller: _currentSecretController,
                autofillHints: const [AutofillHints.password],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (pin &&
                  validators.transactionPin(_currentSecretController.text) !=
                      null) {
                _showMessage('Enter a 4-digit PIN.');
                return;
              }
              if (!pin && _currentSecretController.text.isEmpty) {
                _showMessage('Enter your current password.');
                return;
              }
              if (pin) {
                await ref
                    .read(verifyCurrentPinProvider.notifier)
                    .submit(_currentSecretController.text);
              } else {
                await ref
                    .read(verifyCurrentPasswordProvider.notifier)
                    .submit(_currentSecretController.text);
              }
              final result = pin
                  ? ref.read(verifyCurrentPinProvider)
                  : ref.read(verifyCurrentPasswordProvider);
              if (!mounted || !dialogContext.mounted) return;
              if (result.isDone) Navigator.pop(dialogContext);
              final message =
                  result.message ??
                  (result.isDone
                      ? 'Current ${pin ? 'PIN' : 'password'} verified.'
                      : 'Verification failed.');
              if (result.isDone) {
                _showSuccessMessage(message);
              } else {
                _showErrorMessage(message);
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    _currentSecretController.clear();
  }
}
