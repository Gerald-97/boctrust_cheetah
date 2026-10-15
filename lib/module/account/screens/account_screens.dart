import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/app_router.dart';
import '../../../app/auth_navigation_provider.dart';
import '../../../app/boc_icons.dart';
import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../../app/theme_controller.dart';
import '../../../utils/validators.dart' as validators;
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../component/password_strength_component.dart';
import '../../component/text_fields.dart';
import '../../home/model/user_home_model.dart';
import '../../home/provider/home_provider.dart';
import '../../kyc/model/kyc_contact_requirement.dart';
import '../../onboarding/model/auth_enums.dart';
import '../../onboarding/model/auth_flow_models.dart';
import '../../onboarding/model/remembered_biometric_profile.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../../onboarding/provider/biometric_login_provider.dart';
import '../../onboarding/provider/recovery_providers.dart';
import '../../onboarding/provider/security_action_providers.dart';
import '../../onboarding/provider/test_otp_provider.dart';
import '../../onboarding/screens/auth_widgets.dart';
import '../model/account_preferences.dart';
import '../model/user_profile_model.dart';
import '../model/withdrawal_bank_models.dart';
import '../provider/account_deletion_provider.dart';
import '../provider/account_preferences_provider.dart';
import '../provider/user_providers.dart';
import '../provider/withdrawal_bank_providers.dart';
import 'contact_verification.dart';

part 'account_control_screens.dart';
part 'linked_bank_accounts_screen.dart';

enum _AccountPage {
  account,
  securityCenter,
  deleteAccount,
  accountStatement,
  preferences,
  myProfile,
  notificationPreferences,
  accessibilityPreferences,
  linkedBanks,
  loans,
  cards,
}

/// The Account tab and everything reached from it.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen.account({super.key}) : _page = _AccountPage.account;
  const AccountScreen.securityCenter({super.key})
    : _page = _AccountPage.securityCenter;
  const AccountScreen.deleteAccount({super.key})
    : _page = _AccountPage.deleteAccount;
  const AccountScreen.accountStatement({super.key})
    : _page = _AccountPage.accountStatement;
  const AccountScreen.preferences({super.key})
    : _page = _AccountPage.preferences;
  const AccountScreen.myProfile({super.key}) : _page = _AccountPage.myProfile;
  const AccountScreen.notificationPreferences({super.key})
    : _page = _AccountPage.notificationPreferences;
  const AccountScreen.accessibilityPreferences({super.key})
    : _page = _AccountPage.accessibilityPreferences;
  const AccountScreen.linkedBanks({super.key})
    : _page = _AccountPage.linkedBanks;
  const AccountScreen.loans({super.key}) : _page = _AccountPage.loans;
  const AccountScreen.cards({super.key}) : _page = _AccountPage.cards;

  final _AccountPage _page;

  @override
  ConsumerState<AccountScreen> createState() => _AccountPageState();
}

/// Owns the text controllers the account sheets use for passwords, PINs and
/// one-time codes, for as long as its page is open.
class _AccountPageState extends FlowPageState<AccountScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _currentSecretController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _currentSecretController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _confirmSignOut() => confirmSignOut(context, ref);

  Future<void> _openAuthDestination(
    AuthDestination destination, {
    AuthNavigationMode mode = AuthNavigationMode.push,
  }) => openAuthDestination(ref, destination, mode: mode);

  @override
  Widget build(BuildContext context) => popScope(switch (widget._page) {
    _AccountPage.account => _accountScreen(),
    _AccountPage.securityCenter => _securityCenterScreen(),
    _AccountPage.deleteAccount => _deleteAccountScreen(),
    _AccountPage.accountStatement => _accountStatementScreen(),
    _AccountPage.preferences => _preferencesScreen(),
    _AccountPage.myProfile => _myProfileScreen(),
    _AccountPage.notificationPreferences => _notificationPreferencesScreen(),
    _AccountPage.accessibilityPreferences => _accessibilityPreferencesScreen(),
    _AccountPage.linkedBanks => _linkedBankAccountsScreen(),
    _AccountPage.loans => _comingSoonScreen(
      capability: FeatureCapability.loans,
      title: 'Loans',
      icon: IconsaxPlusLinear.percentage_circle,
      message:
          "Loans aren't part of the Cheetah app yet — this release is focused on Savings.",
    ),
    _AccountPage.cards => _comingSoonScreen(
      capability: FeatureCapability.cards,
      title: 'Cards',
      icon: IconsaxPlusLinear.card,
      message:
          "Virtual and physical debit cards aren't part of the Cheetah app yet. This release is focused on Savings.",
    ),
  });
}

/// Which credential the security-check overlay was asked to verify.
///
/// The chooser returns this instead of invoking a callback captured from the
/// page's `State`, so the launcher can re-check `mounted` before acting.
enum SecurityCheckMethod { password, pin }

extension _AccountScreens on _AccountPageState {
  Widget _comingSoonScreen({
    required FeatureCapability capability,
    required String title,
    required IconData icon,
    required String message,
  }) {
    assertPlaceholderFor(capability, FeatureAvailability.comingSoon);
    return AppScaffold(
      title: title,
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
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
      icon: IconsaxPlusLinear.bank,
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
      onSectionSelected: goSection,
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(
            bottom: BocSpace.lg,
          ).clearOfNav(context),
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
                  icon: IconsaxPlusLinear.profile,
                  title: 'My profile',
                  subtitle: 'Personal details and verification',
                  onTap: () => go(AppRoutes.myProfile),
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.shield_tick,
                  title: 'Account tier',
                  subtitle: 'Tier ${profile?.tier ?? '—'} · View limits',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.tierOverview),
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.document_text,
                  title: 'Account statement',
                  subtitle: 'Request a statement by email',
                  onTap: () => go(AppRoutes.accountStatement),
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
                  icon: IconsaxPlusLinear.people,
                  title: 'Manage beneficiaries',
                  subtitle: 'People you send money to',
                  onTap: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.manageBeneficiaries),
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.shield,
                  title: 'Security Center',
                  subtitle: 'Password, PIN, devices and protection',
                  onTap: () => go(AppRoutes.securitySettings),
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.setting_4,
                  title: 'Preferences',
                  subtitle: 'Notifications, accessibility and theme',
                  onTap: () => go(AppRoutes.preferences),
                ),
              ],
            ),
            SettingsGroup(
              caption: 'Support',
              children: [
                // No support API exists, so there is no ticket state or reply
                // time to report. Only the published contact details are shown.
                SettingsTile(
                  icon: IconsaxPlusLinear.message,
                  title: 'Chat with support',
                  subtitle: 'Not available yet',
                  trailing: SmallPill.unavailable('Unavailable'),
                  onTap: () => showMessage(
                    'In-app chat is not available yet. Please call or email '
                    'support.',
                  ),
                ),
                const SettingsTile(
                  icon: IconsaxPlusLinear.call,
                  title: 'Call customer care',
                  subtitle: '+234 906 464 1439 · 0703 973 9086',
                ),
                const SettingsTile(
                  icon: IconsaxPlusLinear.sms,
                  title: 'Email support',
                  subtitle: 'info@boctrustmfb.com',
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.shield_security,
                  title: 'Privacy Policy',
                  subtitle: 'How we collect and protect your information',
                  onTap: () => go(AppRoutes.privacyPolicy),
                ),
                SettingsTile(
                  icon: IconsaxPlusLinear.document_text,
                  title: 'Terms & Conditions',
                  subtitle: 'Rules for using BOCTRUST services',
                  onTap: () => go(AppRoutes.terms),
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
                icon: IconsaxPlusLinear.logout,
                label: 'Sign out',
                isLoading: ref.watch(logoutProvider).isLoading,
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
    final phoneNumber = profile?.phoneNumber?.trim();
    final hasPhoneNumber = phoneNumber?.isNotEmpty == true;
    final hasVerifiedPhone = isPhoneReadyForKyc(profile);
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
      onBack: back,
      onSectionSelected: goSection,
      showBottomNavigation: false,
      body: ListView(
        padding: const EdgeInsets.only(top: BocSpace.xs, bottom: BocSpace.lg),
        children: [
          SettingsGroup(
            children: [
              SettingsTile(
                icon: IconsaxPlusLinear.personalcard,
                title: 'Name',
                // displayName falls back to a generic label; show the gap
                // honestly instead of presenting that label as a name.
                subtitle: _profileName(profile) ?? 'Not provided yet',
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.sms,
                title: 'Registered identifier',
                subtitle: identifier,
              ),
              if (profile?.email != null)
                SettingsTile(
                  icon: IconsaxPlusLinear.sms_tracking,
                  title: 'Email verification',
                  subtitle: profile!.isVerifiedEmail
                      ? 'Verified'
                      : 'Verify ${profile.email}',
                  trailing: profile.isVerifiedEmail
                      ? SmallPill.success('Verified')
                      : null,
                  onTap: profile.isVerifiedEmail
                      ? null
                      : () => showContactVerificationSheet(
                          phone: false,
                          initialValue: profile.email,
                        ),
                ),
              if (profile != null)
                SettingsTile(
                  icon: IconsaxPlusLinear.mobile,
                  title: hasPhoneNumber ? 'Phone verification' : 'Phone number',
                  subtitle: hasVerifiedPhone
                      ? 'Verified'
                      : hasPhoneNumber
                      ? 'Verify $phoneNumber'
                      : 'Add phone number',
                  trailing: hasVerifiedPhone
                      ? SmallPill.success('Verified')
                      : null,
                  onTap: hasVerifiedPhone
                      ? null
                      : () => showContactVerificationSheet(
                          phone: true,
                          initialValue: hasPhoneNumber ? phoneNumber : null,
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
                icon: IconsaxPlusLinear.trash,
                title: 'Delete account',
                subtitle: 'Close your account permanently',
                titleColor: context.bocColors.errorText,
                onTap: () => go(AppRoutes.deleteAccount),
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
                  showSuccessMessage(result.message ?? 'Password updated.');
                } else {
                  showErrorMessage(result.message ?? 'Password update failed.');
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
                  showSuccessMessage(
                    result.message ?? 'Transaction PIN updated.',
                  );
                } else {
                  showErrorMessage(
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
              icon: IconsaxPlusLinear.key,
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
                    label: awaitingOtp
                        ? 'Verify code'
                        : awaitingPin
                        ? 'Reset PIN'
                        : 'Send code',
                    isLoading: state.isLoading,
                    onPressed: () async {
                      if (state.isLoading) return;
                      final notifier = modalRef.read(
                        pinRecoveryProvider.notifier,
                      );
                      if (awaitingOtp) {
                        if (validators.otp(_otpController.text) != null) {
                          showMessage('Enter the 6-digit code.');
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
                          showMessage('Choose a PIN that is hard to guess.');
                          return;
                        }
                        if (_confirmPinController.text != _pinController.text) {
                          showMessage('PINs do not match.');
                          return;
                        }
                        await notifier.reset(_pinController.text);
                        final result = modalRef.read(pinRecoveryProvider);
                        if (result.data?.stage == RecoveryFlowStage.completed &&
                            sheetContext.mounted) {
                          Navigator.pop(sheetContext);
                          if (mounted) {
                            showSuccessMessage(
                              result.message ?? 'Transaction PIN reset.',
                            );
                          }
                        }
                        return;
                      }
                      final identifier = _identifierController.text.trim();
                      if (identifier.isEmpty) {
                        showMessage('Enter your email or phone number.');
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
        icon: IconsaxPlusLinear.shield_tick,
        title: 'Security check',
        subtitle: 'Choose how you want to verify that it is you.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppActionSheetOption(
              key: const Key('security-password-option'),
              icon: IconsaxPlusLinear.password_check,
              title: 'Verify current password',
              subtitle: 'Use your account sign-in password',
              onTap: () =>
                  Navigator.pop(sheetContext, SecurityCheckMethod.password),
            ),
            const SizedBox(height: 12),
            AppActionSheetOption(
              key: const Key('security-pin-option'),
              icon: IconsaxPlusLinear.key_square,
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
                showMessage('Enter a 4-digit PIN.');
                return;
              }
              if (!pin && _currentSecretController.text.isEmpty) {
                showMessage('Enter your current password.');
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
                showSuccessMessage(message);
              } else {
                showErrorMessage(message);
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
