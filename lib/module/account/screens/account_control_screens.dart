part of 'account_screens.dart';

/// Security Center, delete account and statement request. Controls whose
/// contract does not exist yet stay visible and explain themselves; none of
/// them shows sample devices, balances or results.
extension _AccountControlScreens on _AccountPageState {
  bool _isAvailable(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  Widget _notAvailableTag() => const SmallPill(text: 'Not available yet');

  Widget _securityCenterScreen() {
    final profile = ref.watch(userProfileProvider).data;
    // These controls are shells until each feature is built; switching a
    // capability on without a real handler fails fast in debug.
    for (final capability in const [
      FeatureCapability.biometricTransfers,
      FeatureCapability.freezeAccount,
    ]) {
      assertPlaceholderFor(capability, FeatureAvailability.unavailable);
    }
    return AppScaffold(
      title: 'Security Center',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          SettingsGroup(
            caption: 'Sign-in and approvals',
            children: [
              _biometricLoginTile(),
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.finger_scan,
                title: 'Fingerprint for transfers',
                subtitle: 'Approve transfers with your fingerprint',
                value: false,
                onChanged: null,
                trailing: _notAvailableTag(),
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.password_check,
                title: 'Password',
                subtitle: 'Change your account password',
                onTap: _showChangePasswordDialog,
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.lock,
                title: 'Transaction PIN',
                subtitle: profile?.isCreatedPin == true
                    ? 'Change your 4-digit PIN'
                    : 'Create your 4-digit PIN',
                onTap: profile?.isCreatedPin == true
                    ? _showChangePinDialog
                    : () =>
                          _openAuthDestination(AuthDestination.createFirstPin),
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.key,
                title: 'Forgot transaction PIN',
                subtitle: 'Verify your account and choose a new PIN',
                onTap: _showPinRecoverySheet,
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.shield_tick,
                title: 'Security checks',
                subtitle: 'Verify your current password or PIN',
                onTap: _showSecurityCheckChooser,
              ),
            ],
          ),
          SettingsGroup(
            caption: 'Account protection',
            children: [
              SettingsTile(
                icon: IconsaxPlusLinear.devices,
                title: 'Device management',
                subtitle: "See where you're signed in",
                trailing: _isAvailable(FeatureCapability.deviceSessions)
                    ? null
                    : _notAvailableTag(),
                onTap: () => BocUnavailableSheet.show(
                  context,
                  title: 'Device management is not available yet',
                ),
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.mobile,
                title: 'Change mobile number',
                subtitle: 'Update the number linked to your account',
                trailing: _isAvailable(FeatureCapability.changeMobile)
                    ? null
                    : _notAvailableTag(),
                onTap: () => BocUnavailableSheet.show(
                  context,
                  title: 'Changing your mobile number is not available yet',
                ),
              ),
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.pause_circle,
                title: 'Freeze account',
                subtitle: 'Temporarily block all transactions',
                value: false,
                onChanged: null,
                trailing: _notAvailableTag(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _biometricLoginTile() {
    final biometric = ref.watch(biometricLoginProvider);
    final (icon, title) = switch (biometric.presentation) {
      BiometricPresentation.faceId => (IconsaxPlusLinear.scan, 'Face ID login'),
      BiometricPresentation.touchId => (
        IconsaxPlusLinear.finger_scan,
        'Touch ID login',
      ),
      BiometricPresentation.fingerprint => (
        IconsaxPlusLinear.finger_scan,
        'Fingerprint login',
      ),
      null => (IconsaxPlusLinear.finger_scan, 'Biometric login'),
    };
    final hydrating = biometric.phase == BiometricLoginPhase.hydrating;
    final unavailable = biometric.phase == BiometricLoginPhase.unavailable;
    final subtitle = unavailable
        ? biometric.message ?? 'Not available on this device'
        : hydrating
        ? 'Checking this device…'
        : biometric.isBusy
        ? 'Please wait…'
        : 'Sign in without typing your password';
    return SettingsTile.toggle(
      icon: icon,
      title: title,
      subtitle: subtitle,
      value: biometric.isEnabled,
      onChanged: hydrating || unavailable || biometric.isBusy
          ? null
          : (enable) => enable
                ? _showBiometricEnrollmentDialog()
                : _disableBiometricLogin(),
      trailing: unavailable ? _notAvailableTag() : null,
    );
  }

  /// Confirms the current password, then the device biometric, before
  /// remembering this account for biometric login.
  Future<void> _showBiometricEnrollmentDialog() async {
    _currentSecretController.clear();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Consumer(
        builder: (dialogContext, ref, _) {
          final busy = ref.watch(biometricLoginProvider).isBusy;
          return AlertDialog(
            scrollable: true,
            title: const Text('Turn on biometric login'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your current BOCTRUST password to continue.',
                  ),
                  const SizedBox(height: 12),
                  AppPasswordField(
                    label: 'Current password',
                    controller: _currentSecretController,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password'
                        : null,
                    autofillHints: const [AutofillHints.password],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (formKey.currentState?.validate() != true) return;
                        final result = await ref
                            .read(biometricLoginProvider.notifier)
                            .enable(_currentSecretController.text);
                        if (!mounted || !dialogContext.mounted) return;
                        if (result.succeeded) {
                          Navigator.pop(dialogContext);
                          showSuccessMessage('Biometric login is on.');
                        } else if (result.cancelled) {
                          Navigator.pop(dialogContext);
                        } else {
                          showErrorMessage(
                            result.message ??
                                'We could not turn on biometric login.',
                          );
                        }
                      },
                child: Text(busy ? 'Please wait…' : 'Continue'),
              ),
            ],
          );
        },
      ),
    );
    if (!mounted) return;
    _currentSecretController.clear();
  }

  Future<void> _disableBiometricLogin() async {
    final result = await ref.read(biometricLoginProvider.notifier).disable();
    if (!mounted) return;
    if (result.succeeded) {
      showSuccessMessage('Biometric login is off.');
    } else if (!result.cancelled && result.message != null) {
      showErrorMessage(result.message!);
    }
  }

  Widget _deleteAccountScreen() {
    final theme = Theme.of(context);
    final eligibility = ref.watch(accountDeletionEligibilityProvider);
    return AppScaffold(
      title: 'Delete account',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(BocSpace.gutter),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Before you delete your account',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: BocSpace.sm),
                for (final line in const [
                  'Your balance across all accounts must be zero.',
                  'Your savings plans and linked banks will be closed.',
                  'You will be signed out on every device.',
                  'This cannot be undone.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: BocSpace.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: context.bocColors.textTertiary,
                        ),
                        const SizedBox(width: BocSpace.xs),
                        Expanded(
                          child: Text(line, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ),
            child: PrimaryButton(
              label: 'Continue',
              isLoading: eligibility.isLoading,
              onPressed: _startAccountDeletion,
            ),
          ),
        ],
      ),
    );
  }

  /// Server eligibility → destructive confirmation → current-PIN check →
  /// delete. Each step only proceeds on an explicit, successful result.
  Future<void> _startAccountDeletion() async {
    if (!ref
        .read(featureAvailabilityProvider(FeatureCapability.accountDeletion))
        .isAvailable) {
      await BocUnavailableSheet.show(
        context,
        title: 'Account deletion is not available yet',
      );
      return;
    }
    await ref.read(accountDeletionEligibilityProvider.notifier).load();
    if (!mounted) return;
    final result = ref.read(accountDeletionEligibilityProvider);
    final eligibility = result.data;
    if (!result.isDone || eligibility == null) {
      showErrorMessage(result.message ?? 'We could not check your account.');
      return;
    }
    if (!eligibility.canDelete) {
      final moveMoney = await AppConfirmSheet.show(
        context,
        title: 'Delete account',
        message:
            'You currently have ${eligibility.blockingBalance ?? 'money'} '
            "across your accounts. You'll need to withdraw or move this out "
            'before you can delete your account.',
        confirmLabel: 'Move money out',
      );
      if (moveMoney && mounted) {
        Navigator.of(context).pushNamed(AppRoutes.sendHub);
      }
      return;
    }
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Delete your account?',
      message:
          'Your account will be closed and you will be signed out. This '
          'cannot be undone.',
      confirmLabel: 'Delete account',
      cancelLabel: 'Keep my account',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final verified = await _verifyPinForDeletion();
    if (!verified || !mounted) return;
    await ref.read(accountDeletionProvider.notifier).delete();
    if (!mounted) return;
    final deletion = ref.read(accountDeletionProvider);
    if (!deletion.isDone) {
      showErrorMessage(deletion.message ?? 'We could not delete your account.');
      return;
    }
    // A deleted account must not stay remembered on this device. The
    // deletion notifier is still a stub, so this is its only success path.
    await ref.read(biometricLoginProvider.notifier).forgetEnrollment();
    if (!mounted) return;
    await ref.read(logoutProvider.notifier).logout();
  }

  /// Resolves true only after the server accepts the current PIN. A rejected
  /// PIN keeps the sheet open with the server's message.
  Future<bool> _verifyPinForDeletion() async {
    ref.invalidate(verifyCurrentPinProvider);
    final verified = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => const _DeletionPinSheet(),
    );
    return verified ?? false;
  }

  Widget _preferencesScreen() {
    final themeMode = ref.watch(themeControllerProvider).mode;
    return AppScaffold(
      title: 'Preferences',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          SettingsGroup(
            children: [
              SettingsTile(
                icon: IconsaxPlusLinear.notification,
                title: 'Notifications',
                subtitle: 'Choose what we tell you about',
                onTap: () => go(AppRoutes.notificationPreferences),
              ),
              SettingsTile(
                icon: Icons.accessibility_new_rounded,
                title: 'Accessibility',
                subtitle: 'Text size, contrast and bold text',
                onTap: () => go(AppRoutes.accessibilityPreferences),
              ),
            ],
          ),
          const SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: BocSpace.gutter),
            child: ThemeSelector(
              value: themeMode,
              onChanged: (mode) =>
                  ref.read(themeControllerProvider.notifier).selectMode(mode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notificationPreferencesScreen() {
    final prefs = ref.watch(notificationPreferencesProvider);
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    return AppScaffold(
      title: 'Notifications',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ),
            child: Text(
              'These choices are saved on this device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SettingsGroup(
            children: [
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.arrow_swap,
                title: 'Transactions',
                subtitle: 'Money in and out of your accounts',
                value: prefs.transactions,
                onChanged: (value) =>
                    notifier.update(prefs.copyWith(transactions: value)),
              ),
              SettingsTile.toggle(
                icon: BocIcons.savings,
                title: 'Savings reminders',
                subtitle: 'Upcoming auto-saves and goal progress',
                value: prefs.savingsReminders,
                onChanged: (value) =>
                    notifier.update(prefs.copyWith(savingsReminders: value)),
              ),
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.notification_bing,
                title: 'Offers and news',
                subtitle: 'New products and promotions',
                value: prefs.marketing,
                onChanged: (value) =>
                    notifier.update(prefs.copyWith(marketing: value)),
              ),
              const SettingsTile.toggle(
                icon: IconsaxPlusLinear.shield,
                title: 'Security alerts',
                subtitle: 'Sign-ins and account changes are always sent',
                value: true,
                onChanged: null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accessibilityPreferencesScreen() {
    final prefs = ref.watch(accessibilityPreferencesProvider);
    final notifier = ref.read(accessibilityPreferencesProvider.notifier);
    return AppScaffold(
      title: 'Accessibility',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.xs,
            ),
            child: Text(
              'Text size',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.lg,
            ),
            child: BocSegmentedControl<TextSizePreference>(
              segments: [
                for (final size in TextSizePreference.values)
                  (value: size, label: size.label),
              ],
              selected: prefs.textSize,
              onChanged: (size) =>
                  notifier.update(prefs.copyWith(textSize: size)),
            ),
          ),
          SettingsGroup(
            children: [
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.colorfilter,
                title: 'High contrast',
                subtitle: 'Darker text and borders',
                value: prefs.highContrast,
                onChanged: (value) =>
                    notifier.update(prefs.copyWith(highContrast: value)),
              ),
              SettingsTile.toggle(
                icon: IconsaxPlusLinear.text_bold,
                title: 'Bold text',
                subtitle: 'Make all text bold',
                value: prefs.boldText,
                onChanged: (value) =>
                    notifier.update(prefs.copyWith(boldText: value)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _accountStatementScreen() {
    assertPlaceholderFor(
      FeatureCapability.accountStatement,
      FeatureAvailability.unavailable,
    );
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Account statement',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(BocSpace.gutter),
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Request statement of account',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: BocSpace.xs),
                Text(
                  'Your statement will be sent to the email address '
                  'registered with your account.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: BocSpace.lg),
                _StatementPeriodField(
                  key: const Key('statement-period'),
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ),
            child: PrimaryButton(
              label: 'Request statement',
              onPressed: () => BocUnavailableSheet.show(
                context,
                title: 'Statement requests are not available yet',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks a statement period of up to 12 months, ending no later than today.
class _StatementPeriodField extends StatefulWidget {
  const _StatementPeriodField({required this.onChanged, super.key});

  final ValueChanged<DateTimeRange> onChanged;

  @override
  State<_StatementPeriodField> createState() => _StatementPeriodFieldState();
}

class _StatementPeriodFieldState extends State<_StatementPeriodField> {
  DateTimeRange? _range;

  Future<void> _pick() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      lastDate: today,
      initialDateRange: _range,
      helpText: 'Statement period (up to 12 months)',
    );
    if (picked == null || !mounted) return;
    final latestStart = DateTime(
      picked.end.year - 1,
      picked.end.month,
      picked.end.day,
    );
    final range = picked.start.isBefore(latestStart)
        ? DateTimeRange(start: latestStart, end: picked.end)
        : picked;
    setState(() => _range = range);
    widget.onChanged(range);
  }

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('d MMM yyyy');
    final range = _range;
    return InkWell(
      borderRadius: BorderRadius.circular(BocRadius.sm),
      onTap: _pick,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Statement period',
          suffixIcon: Icon(IconsaxPlusLinear.calendar),
        ),
        child: Text(
          range == null
              ? 'Choose dates'
              : '${format.format(range.start)} – ${format.format(range.end)}',
        ),
      ),
    );
  }
}

/// Collects the current PIN for account deletion and pops `true` only once
/// the server verifies it. Owns its controller so it outlives the close
/// animation.
class _DeletionPinSheet extends ConsumerStatefulWidget {
  const _DeletionPinSheet();

  @override
  ConsumerState<_DeletionPinSheet> createState() => _DeletionPinSheetState();
}

class _DeletionPinSheetState extends ConsumerState<_DeletionPinSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref.read(verifyCurrentPinProvider.notifier).submit(_controller.text);
    if (!mounted) return;
    if (ref.read(verifyCurrentPinProvider).isDone) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = ref.watch(verifyCurrentPinProvider);
    final theme = Theme.of(context);
    final message = check.message;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        BocSpace.gutter,
        0,
        BocSpace.gutter,
        BocSpace.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your transaction PIN',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: BocSpace.xs),
          Text(
            'We need to confirm it is you before deleting your account.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BocSpace.lg),
          AppTextField(
            label: 'Current PIN',
            controller: _controller,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          if (check.isError && message != null) ...[
            const SizedBox(height: BocSpace.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.bocColors.errorText,
                ),
              ),
            ),
          ],
          const SizedBox(height: BocSpace.lg),
          PrimaryButton(
            label: 'Verify and delete',
            isLoading: check.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
