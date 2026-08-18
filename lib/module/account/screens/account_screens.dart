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

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final result = words.map((word) => word[0].toUpperCase()).join();
    return result.isEmpty ? 'BC' : result;
  }

  Widget _accountScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.data;
    final session = ref.watch(authSessionProvider);
    if (profileState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
      AppThemeMode.system => Icons.settings_brightness_outlined,
    };
    final displayName = profile?.displayName ?? 'BOCTrust customer';
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
                SettingsTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Account provider',
                  subtitle: 'BOCTrust MFB',
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
                  subtitle: 'Rules for using BOCTrust',
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
    final session = ref.read(authSessionProvider);
    final identifier = session?.email ?? session?.phoneNumber;
    if (identifier == null) {
      _showMessage('Your session does not include a login identifier.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change password'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Current password',
                controller: _currentSecretController,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'New password',
                controller: _passwordController,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirm new password',
                controller: _confirmPasswordController,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final password = _passwordController.text;
              final validation = validators.isPasswordValid(password);
              if (_currentSecretController.text.isEmpty || validation != null) {
                _showMessage(validation ?? 'Enter your current password.');
                return;
              }
              if (_confirmPasswordController.text != password) {
                _showMessage('Passwords do not match.');
                return;
              }
              await ref
                  .read(changePasswordProvider.notifier)
                  .submit(
                    identifier: identifier,
                    currentPassword: _currentSecretController.text,
                    newPassword: password,
                  );
              final result = ref.read(changePasswordProvider);
              if (!mounted || !dialogContext.mounted) return;
              if (result.isDone) Navigator.pop(dialogContext);
              if (result.isDone) {
                _showSuccessMessage(result.message ?? 'Password updated.');
              } else {
                _showErrorMessage(result.message ?? 'Password update failed.');
              }
            },
            child: const Text('Update'),
          ),
        ],
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
    final session = ref.read(authSessionProvider);
    final identifier = session?.email ?? session?.phoneNumber;
    if (identifier == null) {
      _showMessage('Your session does not include a login identifier.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change transaction PIN'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(
                label: 'Current PIN',
                controller: _currentSecretController,
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'New PIN',
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                label: 'Confirm new PIN',
                controller: _confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (validators.transactionPin(_currentSecretController.text) !=
                      null ||
                  validators.transactionPin(_pinController.text) != null) {
                _showMessage('Enter valid 4-digit PINs.');
                return;
              }
              if (_confirmPinController.text != _pinController.text) {
                _showMessage('PINs do not match.');
                return;
              }
              await ref
                  .read(changePinProvider.notifier)
                  .submit(
                    identifier: identifier,
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
                          : 'BOCTrust will send a one-time verification code.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 18),
                    if (awaitingOtp) ...[
                      PinInputField(
                        pinCtrl: _otpController,
                        isActive: !state.isLoading,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 10),
                      OtpExpiryLabel(expiresAt: state.data?.otpExpiresAt),
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
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 10),
                      OtpExpiryLabel(expiresAt: state.data?.otpExpiresAt),
                    ] else if (awaitingPin) ...[
                      PinInputField(
                        pinLength: 4,
                        pinCtrl: _pinController,
                        obscureText: true,
                        isActive: !state.isLoading,
                        onChanged: (_) {},
                      ),
                      const SizedBox(height: 14),
                      PinInputField(
                        pinLength: 4,
                        pinCtrl: _confirmPinController,
                        obscureText: true,
                        isActive: !state.isLoading,
                        onChanged: (_) {},
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
                          if (validators.transactionPin(_pinController.text) !=
                              null) {
                            _showMessage('Enter a 4-digit PIN.');
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
        content: AppTextField(
          label: pin ? 'Current PIN' : 'Current password',
          controller: _currentSecretController,
          obscureText: true,
          keyboardType: pin ? TextInputType.number : null,
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
