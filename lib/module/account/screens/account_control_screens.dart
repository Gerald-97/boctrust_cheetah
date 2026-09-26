part of '../../app_flow/app_flow_navigator.dart';

/// Security Center, delete account and statement request. Controls whose
/// contract does not exist yet stay visible and explain themselves; none of
/// them shows sample devices, balances or results.
extension AccountControlScreens on AppFlowNavigatorState {
  bool _isAvailable(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  Widget _notAvailableTag() => const SmallPill(text: 'Not available yet');

  Widget _securityCenterScreen() {
    final profile = ref.watch(userProfileProvider).data;
    final biometricLogin = _isAvailable(FeatureCapability.biometricLogin);
    final biometricTransfers = _isAvailable(
      FeatureCapability.biometricTransfers,
    );
    final freeze = _isAvailable(FeatureCapability.freezeAccount);
    return AppScaffold(
      title: 'Security Center',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          SettingsGroup(
            caption: 'Sign-in and approvals',
            children: [
              SettingsTile.toggle(
                icon: Icons.face_rounded,
                title: 'Face ID login',
                subtitle: 'Use face recognition to sign in',
                value: false,
                onChanged: biometricLogin ? (_) {} : null,
                trailing: biometricLogin ? null : _notAvailableTag(),
              ),
              SettingsTile.toggle(
                icon: Icons.fingerprint_rounded,
                title: 'Fingerprint for transfers',
                subtitle: 'Approve transfers with your fingerprint',
                value: false,
                onChanged: biometricTransfers ? (_) {} : null,
                trailing: biometricTransfers ? null : _notAvailableTag(),
              ),
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
                    : () =>
                          _openAuthDestination(AuthDestination.createFirstPin),
              ),
            ],
          ),
          SettingsGroup(
            caption: 'Account protection',
            children: [
              SettingsTile(
                icon: Icons.devices_rounded,
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
                icon: Icons.phone_iphone_rounded,
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
                icon: Icons.ac_unit_rounded,
                title: 'Freeze account',
                subtitle: 'Temporarily block all transactions',
                value: false,
                onChanged: freeze ? (_) {} : null,
                trailing: freeze ? null : _notAvailableTag(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _deleteAccountScreen() {
    final theme = Theme.of(context);
    final eligibility = ref.watch(accountDeletionEligibilityProvider);
    return AppScaffold(
      title: 'Delete account',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
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
      _showErrorMessage(result.message ?? 'We could not check your account.');
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
      if (moveMoney && mounted) _go(AppScreen.sendHub);
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
      _showErrorMessage(
        deletion.message ?? 'We could not delete your account.',
      );
      return;
    }
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

  Widget _accountStatementScreen() {
    _assertPlaceholderFor(
      FeatureCapability.accountStatement,
      FeatureAvailability.unavailable,
    );
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Account statement',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
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
          suffixIcon: Icon(Icons.calendar_month_rounded),
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
