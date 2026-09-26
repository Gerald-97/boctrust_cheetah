part of '../../app_flow/app_flow_navigator.dart';

/// Which credential the security-check overlay was asked to verify.
///
/// The chooser returns this instead of invoking a callback captured from the
/// navigator's `State`, so the launcher can re-check `mounted` before acting.
enum SecurityCheckMethod { password, pin }

extension AccountScreens on AppFlowNavigatorState {
  Widget _routePreviewScreen() {
    final route = appPreviewRouteForRoute(widget.initialRouteName);
    if (route == AppPreviewRoute.flexTopUp ||
        route == AppPreviewRoute.bankTransferFunding) {
      return _addMoneyScreen();
    }
    if (widget.initialRouteName?.startsWith('/savings/') == true ||
        route == AppPreviewRoute.cardFunding) {
      final title = switch (route) {
        AppPreviewRoute.flexWithdraw => 'Withdrawals',
        AppPreviewRoute.flexStatement => 'Savings statements',
        AppPreviewRoute.flexSettings => 'Auto-save',
        AppPreviewRoute.cardFunding => 'Card funding',
        _ => 'Savings plans',
      };
      final singular =
          route == AppPreviewRoute.flexSettings ||
          route == AppPreviewRoute.cardFunding;
      return _savingsUnavailableScreen(
        capability: switch (route) {
          AppPreviewRoute.flexWithdraw => FeatureCapability.flexWithdraw,
          AppPreviewRoute.flexStatement => FeatureCapability.flexStatement,
          AppPreviewRoute.flexSettings => FeatureCapability.flexAutoSave,
          AppPreviewRoute.cardFunding => FeatureCapability.cardFunding,
          _ => FeatureCapability.savingsPlansView,
        },
        title: title,
        message: '$title ${singular ? 'is' : 'are'} not available yet.',
      );
    }
    // These routes once rendered sample customer activity. With no
    // transaction or beneficiary service they only explain the gap.
    switch (route) {
      case AppPreviewRoute.transactionHistory:
        if (ref
            .watch(
              featureAvailabilityProvider(FeatureCapability.transactionHistory),
            )
            .isAvailable) {
          return _transactionHistoryScreen();
        }
        return _transactionUnavailableScreen(
          capability: FeatureCapability.transactionHistory,
          title: 'Transactions',
          section: AppSection.payments,
          heading: 'Transaction history is unavailable',
          message: 'Your transaction history cannot be displayed yet.',
        );
      case AppPreviewRoute.paymentWebView:
        return _transactionUnavailableScreen(
          capability: FeatureCapability.cardFunding,
          title: 'Payment',
          section: AppSection.payments,
          heading: 'Payment checkout is unavailable',
          message: 'Card and hosted checkout payments are not available yet.',
        );
      case AppPreviewRoute.accountBeneficiaries:
        return _transactionUnavailableScreen(
          capability: FeatureCapability.beneficiaries,
          title: 'Beneficiaries',
          section: AppSection.account,
          heading: 'Beneficiaries are unavailable',
          message: 'Saved beneficiaries are not available yet.',
        );
      default:
        break;
    }
    final preview = _previewContentForRoute(route);
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
      case AppPreviewRoute.flexTopUp:
      case AppPreviewRoute.flexWithdraw:
      case AppPreviewRoute.flexStatement:
      case AppPreviewRoute.flexSettings:
      case AppPreviewRoute.targetSort:
      case AppPreviewRoute.lockDetails:
      case AppPreviewRoute.lockAddMoney:
      case AppPreviewRoute.groupContribute:
      case AppPreviewRoute.groupInvite:
      case AppPreviewRoute.groupMembers:
      case AppPreviewRoute.bankTransferFunding:
      case AppPreviewRoute.cardFunding:
      case AppPreviewRoute.accountBeneficiaries:
      case AppPreviewRoute.transactionHistory:
      case AppPreviewRoute.paymentWebView:
        return (
          title: 'Unavailable',
          icon: Icons.info_outline,
          color: BocColors.gold,
          section: AppSection.save,
          summary: 'This feature is not available yet.',
          actionLabel: 'Back',
          rows: <(IconData, String, String)>[],
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
            (Icons.chat_bubble_outline_rounded, 'Chat', 'Not available yet'),
            (Icons.phone_outlined, 'Call', '+234 906 464 1439'),
            (Icons.mail_outline_rounded, 'Email', 'info@boctrustmfb.com'),
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
          // Official BOCTRUST handles have not been supplied; no rows are
          // shown rather than another brand's accounts.
          summary: 'BOCTRUST social profiles will be listed here.',
          actionLabel: 'Back',
          rows: <(IconData, String, String)>[],
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
    required FeatureCapability capability,
    required String title,
    required IconData icon,
    required String message,
  }) {
    _assertPlaceholderFor(capability, FeatureAvailability.comingSoon);
    return AppScaffold(
      title: title,
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: ScrollableFill(
        child: Center(
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
                // No subscription service exists, so nothing is offered that
                // would imply the customer will be contacted.
                Text(
                  'Launch notifications are not available yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final colors = context.bocColors;
    final displayName = profile?.displayName ?? 'BOCTRUST customer';
    final identifier =
        profile?.email ??
        profile?.phoneNumber ??
        session?.email ??
        session?.phoneNumber;
    final verified = profile?.isVerifiedAccount == true;

    return AppScaffold(
      title: 'Account',
      activeSection: AppSection.account,
      onSectionSelected: _goSection,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: BocSpace.lg),
          children: [
            if (profileState.isError)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  BocSpace.gutter,
                  0,
                  BocSpace.gutter,
                  BocSpace.sm,
                ),
                child: ApiStateCard(
                  title: 'Profile unavailable',
                  message:
                      profileState.message ?? 'Unable to load your profile.',
                  tone: ApiStateTone.warning,
                  actionLabel: 'Retry',
                  onAction: () => ref.read(userProfileProvider.notifier).load(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BocSpace.gutter,
                BocSpace.xs,
                BocSpace.gutter,
                BocSpace.lg,
              ),
              child: Column(
                children: [
                  ProfileAvatar(
                    displayName: profile?.displayName ?? '',
                    hasImage: profile?.imageUrl?.isNotEmpty ?? false,
                    radius: 40,
                  ),
                  const SizedBox(height: BocSpace.sm),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  if (identifier != null) ...[
                    const SizedBox(height: BocSpace.xxs),
                    Text(
                      identifier,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: BocSpace.xs),
                  if (profileState.isLoading && profile == null)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    SmallPill(
                      text:
                          'Tier ${profile?.tier ?? '—'} · '
                          '${verified ? 'Verified' : 'Verification pending'}',
                      foreground: verified
                          ? colors.successText
                          : colors.warningText,
                      background: verified
                          ? colors.successContainer
                          : colors.warningContainer,
                    ),
                ],
              ),
            ),
            SettingsGroup(
              caption: 'Account details',
              children: [
                SettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'My profile',
                  subtitle: 'Personal details and verification',
                  onTap: () => _go(AppScreen.myProfile),
                ),
                SettingsTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Account tier',
                  subtitle: 'Tier ${profile?.tier ?? '—'} · View limits',
                  onTap: () => _go(AppScreen.tiers),
                ),
                SettingsTile(
                  icon: Icons.trending_up_rounded,
                  title: 'Request limit increase',
                  subtitle: 'Raise your daily transfer limit',
                  trailing: const SmallPill(text: 'Not available yet'),
                  onTap: () => BocUnavailableSheet.show(
                    context,
                    title: 'Limit increases are not available yet',
                  ),
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Account statement',
                  subtitle: 'Request a statement by email',
                  onTap: () => _go(AppScreen.accountStatement),
                ),
              ],
            ),
            SettingsGroup(
              caption: 'Wallet',
              children: [_virtualAccountTile(virtualAccount)],
            ),
            SettingsGroup(
              caption: 'Settings',
              children: [
                SettingsTile(
                  icon: Icons.people_outline_rounded,
                  title: 'Manage beneficiaries',
                  subtitle: 'People you send money to',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.manageBeneficiaries),
                ),
                SettingsTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Linked banks',
                  subtitle: 'Accounts you withdraw to',
                  onTap: () => _go(AppScreen.linkedBanks),
                ),
                SettingsTile(
                  icon: Icons.shield_outlined,
                  title: 'Security Center',
                  subtitle: 'Password, PIN, devices and protection',
                  onTap: () => _go(AppScreen.securityCenter),
                ),
                SettingsTile(
                  icon: Icons.tune_rounded,
                  title: 'Preferences',
                  subtitle: 'Notifications, accessibility and theme',
                  onTap: () => _go(AppScreen.preferences),
                ),
              ],
            ),
            SettingsGroup(
              caption: 'More services',
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
            SettingsGroup(
              caption: 'Support',
              children: [
                // No support API exists, so there is no ticket state or reply
                // time to report. Only the published contact details are shown.
                SettingsTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Chat with support',
                  subtitle: 'Not available yet',
                  trailing: SmallPill.unavailable('Unavailable'),
                  onTap: () => _showMessage(
                    'In-app chat is not available yet. Please call or email '
                    'support.',
                  ),
                ),
                const SettingsTile(
                  icon: Icons.phone_outlined,
                  title: 'Call customer care',
                  subtitle: '+234 906 464 1439 · 0703 973 9086',
                ),
                const SettingsTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Email support',
                  subtitle: 'info@boctrustmfb.com',
                ),
                // No policy-content endpoint and no bundled copy, so these
                // cannot open anything yet.
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Not available in the app yet',
                  trailing: SmallPill.unavailable('Unavailable'),
                  onTap: () => _showMessage(
                    'The privacy policy is not available in the app yet.',
                  ),
                ),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms & Conditions',
                  subtitle: 'Not available in the app yet',
                  trailing: SmallPill.unavailable('Unavailable'),
                  onTap: () => _showMessage(
                    'The terms and conditions are not available in the app yet.',
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                BocSpace.gutter,
                BocSpace.xs,
                BocSpace.gutter,
                BocSpace.xs,
              ),
              child: SecondaryButton(
                icon: Icons.logout_rounded,
                label: ref.watch(logoutProvider).isLoading
                    ? 'Signing out…'
                    : 'Sign out',
                onPressed: ref.watch(logoutProvider).isLoading
                    ? null
                    : _confirmSignOut,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                BocSpace.gutter,
                BocSpace.xs,
                BocSpace.gutter,
                0,
              ),
              child: RegulatoryBadge(),
            ),
          ],
        ),
      ),
    );
  }

  String? _profileName(UserOwnProfileData? profile) {
    final parts = [
      profile?.firstName,
      profile?.lastName,
    ].whereType<String>().map((part) => part.trim()).where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// Personal details and email/phone verification.
  Widget _myProfileScreen() {
    final profile = ref.watch(userProfileProvider).data;
    final session = ref.watch(authSessionProvider);
    final identifier =
        profile?.email ??
        profile?.phoneNumber ??
        session?.email ??
        session?.phoneNumber ??
        'Not available';
    return AppScaffold(
      title: 'My profile',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.badge_outlined,
                title: 'Name',
                // displayName falls back to a generic label; show the gap
                // honestly instead of presenting that label as a name.
                subtitle: _profileName(profile) ?? 'Not provided yet',
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
                      ? SmallPill.success('Verified')
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
                      ? SmallPill.success('Verified')
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
          // Kept apart from everyday actions (and from Sign out on the
          // Account hub) so it cannot be hit by mistake.
          const SizedBox(height: BocSpace.lg),
          SettingsGroup(
            caption: 'Close account',
            children: [
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: 'Delete account',
                subtitle: 'Close your account permanently',
                titleColor: context.bocColors.errorText,
                onTap: () => _go(AppScreen.deleteAccount),
              ),
            ],
          ),
        ],
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
          // Title and actions scroll with the form when the keyboard and
          // large text leave too little height.
          scrollable: true,
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
    if (!mounted) return;
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                      autoValidateMode: autovalidateMode,
                    ),
                    const SizedBox(height: 12),
                    const Text('New PIN'),
                    const SizedBox(height: 8),
                    PinInputField(
                      pinLength: 4,
                      pinCtrl: _pinController,
                      obscureText: true,
                      validator: validators.strongTransactionPin,
                      autoValidateMode: autovalidateMode,
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
                      autoValidateMode: autovalidateMode,
                    ),
                  ],
                ),
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
    if (!mounted) return;
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
                          : 'BOCTRUST will send a one-time verification code.',
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
    if (!mounted) return;
    _identifierController.clear();
    _otpController.clear();
    ref.invalidate(identifierVerificationProvider);
  }

  Future<void> _showPinRecoverySheet() async {
    if (!mounted) return;
    ref.invalidate(pinRecoveryProvider);
    final session = ref.read(authSessionProvider);
    _identifierController.text = session?.email ?? session?.phoneNumber ?? '';
    _otpController.clear();
    _pinController.clear();
    _confirmPinController.clear();
    var channel = PhoneVerificationChannel.sms;
    await AppActionSheet.show<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Consumer(
          builder: (context, modalRef, _) {
            final state = modalRef.watch(pinRecoveryProvider);
            final stage = state.data?.stage ?? RecoveryFlowStage.idle;
            final awaitingOtp = stage == RecoveryFlowStage.awaitingOtp;
            final awaitingPin = stage == RecoveryFlowStage.awaitingNewSecret;
            return AppActionSheet(
              icon: Icons.lock_reset_rounded,
              title: awaitingOtp
                  ? 'Verify your account'
                  : awaitingPin
                  ? 'Choose a new PIN'
                  : 'Reset transaction PIN',
              subtitle: awaitingOtp
                  ? 'Enter the 6-digit code sent to the registered contact.'
                  : awaitingPin
                  ? 'Use four digits that are difficult to guess.'
                  : "We'll send a code to verify your account.",
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                      autoValidateMode: AutovalidateMode.onUserInteraction,
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
                      autoValidateMode: AutovalidateMode.onUserInteraction,
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
                        if (_confirmPinController.text != _pinController.text) {
                          _showMessage('PINs do not match.');
                          return;
                        }
                        await notifier.reset(_pinController.text);
                        final result = modalRef.read(pinRecoveryProvider);
                        if (result.data?.stage == RecoveryFlowStage.completed &&
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
            );
          },
        ),
      ),
    );
    if (!mounted) return;
    ref.read(pinRecoveryProvider.notifier).cancel();
    _identifierController.clear();
    _otpController.clear();
    _pinController.clear();
    _confirmPinController.clear();
  }

  Future<void> _showSecurityCheckChooser() async {
    if (!mounted) return;
    final method = await AppActionSheet.show<SecurityCheckMethod>(
      context: context,
      builder: (sheetContext) => AppActionSheet(
        icon: Icons.verified_user_outlined,
        title: 'Security check',
        subtitle: 'Choose how you want to verify that it is you.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppActionSheetOption(
              key: const Key('security-password-option'),
              icon: Icons.password_rounded,
              title: 'Verify current password',
              subtitle: 'Use your account sign-in password',
              onTap: () =>
                  Navigator.pop(sheetContext, SecurityCheckMethod.password),
            ),
            const SizedBox(height: 12),
            AppActionSheetOption(
              key: const Key('security-pin-option'),
              icon: Icons.pin_outlined,
              title: 'Verify current PIN',
              subtitle: 'Use your 4-digit transaction PIN',
              onTap: () => Navigator.pop(sheetContext, SecurityCheckMethod.pin),
            ),
          ],
        ),
      ),
    );
    if (!mounted || method == null) return;
    await _showCurrentSecretVerificationDialog(
      pin: method == SecurityCheckMethod.pin,
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
    if (!mounted) return;
    _currentSecretController.clear();
  }
}
