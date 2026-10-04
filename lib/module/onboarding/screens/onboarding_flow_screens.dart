part of '../../app_flow/app_flow_navigator.dart';

extension OnboardingFlowScreens on AppFlowNavigatorState {
  Widget _bootstrapScreen() {
    final state = ref.watch(startupGateProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(startupGateProvider.notifier).start);
    }
    final hasError = state.status == ServiceStatus.error;
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 560,
          child: ScrollableFill(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BocLogo(height: 52),
                    const SizedBox(height: 28),
                    if (!hasError) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 18),
                      Text(
                        state.data?.stage == StartupGateStage.loadingProfile
                            ? 'Loading your account…'
                            : 'Starting securely…',
                      ),
                    ] else ...[
                      const Icon(
                        IconsaxPlusLinear.cloud_cross,
                        size: 48,
                        color: BocColors.gold,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        state.message ?? 'Unable to load your account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Retry',
                        onPressed: () => ref
                            .read(startupGateProvider.notifier)
                            .retryProfile(),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _confirmSignOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _onboardingScreen() {
    const slides = <({IconData icon, String title, String description})>[
      (
        icon: IconsaxPlusLinear.strongbox,
        title: 'Save without thinking about it',
        description:
            'Boc Flex Savings grows every day with no lock-in. SmartSave, Fixed Deposit and Padi help you commit to a goal, on your terms.',
      ),
      (
        icon: IconsaxPlusLinear.flag,
        title: 'Reach any goal, your way',
        description:
            'Save toward a goal, lock in a fixed term for a higher rate, or save together with friends — pick whichever fits.',
      ),
      (
        icon: IconsaxPlusLinear.send_2,
        title: 'Send and pay, instantly',
        description:
            'Move money between your BOCTRUST accounts, send to friends and family, or pay bills — all in one place.',
      ),
    ];
    final slide = slides[_onboardingIndex];
    return Scaffold(
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 560,
          child: ScrollableFill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _openAuthDestination(
                        AuthDestination.verificationMethod,
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                  const BocLogo(height: 42),
                  const Spacer(),
                  OnboardingIllustration(icon: slide.icon),
                  const SizedBox(height: 30),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 23),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      slides.length,
                      (index) => GestureDetector(
                        onTap: () => _selectOnboardingIndex(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _onboardingIndex ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == _onboardingIndex
                                ? BocColors.gold
                                : Theme.of(context).dividerColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 5),
                  const RegulatoryBadge(),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: _onboardingIndex == slides.length - 1
                        ? 'Get started'
                        : 'Next',
                    onPressed: _advanceOnboarding,
                  ),
                  TextButton(
                    onPressed: () => _openAuthDestination(
                      AuthDestination.login,
                      mode: AuthNavigationMode.clearStack,
                    ),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _authPage({
    required String title,
    required String subtitle,
    required Widget content,
    required String buttonLabel,
    required VoidCallback onButtonPressed,
    Widget? footer,
    bool showBack = true,
  }) {
    final fields = <Widget>[
      const BocLogo(height: 36),
      const SizedBox(height: 28),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontSize: 22),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.55,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      const SizedBox(height: 28),
      content,
    ];
    final actions = Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: buttonLabel, onPressed: onButtonPressed),
          if (footer != null) ...[const SizedBox(height: 10), footer],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Never render a chevron that cannot navigate: a screen entered with a
        // cleared stack has no history and nothing to pop.
        leading: showBack && _canGoBack
            ? IconButton(
                icon: const Icon(IconsaxPlusLinear.arrow_left_1, size: 19),
                onPressed: _back,
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          maxWidth: 560,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A pinned footer must not consume the form's viewport when a
              // keyboard or landscape window leaves little vertical space, so
              // the footer scrolls with the fields instead.
              //
              // Both cases must keep the SAME widget tree above the fields.
              // Returning two differently shaped trees re-parents every
              // TextFormField the instant the keyboard raises viewInsets. Its
              // FormFieldState is then rebuilt rather than reused, the focus
              // node it owns is disposed, and Flutter closes the input
              // connection — so the keyboard dismisses itself before a
              // character can be typed. Dismissing it drops viewInsets back to
              // zero, which restores the first shape, so it never settles.
              final tight =
                  constraints.maxHeight < 480 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                      children: [
                        ...fields,
                        // Scrolls with the form only when space is tight.
                        if (tight) actions,
                      ],
                    ),
                  ),
                  // Pinned only when there is room for it.
                  if (!tight) actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stateMessage<T>(NotifierState<T> state) {
    if (state.message == null ||
        (!state.isError && state.status != ServiceStatus.blocked)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        state.message!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: BocColors.red, fontSize: 12),
      ),
    );
  }

  bool _validIdentifier(String value) {
    if (_verifyByPhone) {
      return isValidNigerianPhone(value);
    }
    return validators.isEmail(value);
  }

  Widget _phoneChannelSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('SMS'),
            selected: _phoneChannel == PhoneVerificationChannel.sms,
            onSelected: (_) =>
                _selectPhoneChannel(PhoneVerificationChannel.sms),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text('WhatsApp'),
            selected: _phoneChannel == PhoneVerificationChannel.whatsapp,
            onSelected: (_) =>
                _selectPhoneChannel(PhoneVerificationChannel.whatsapp),
          ),
        ),
      ],
    );
  }

  Widget _verifyMethodScreen() {
    final state = ref.watch(signupFlowProvider);
    return _authPage(
      title: 'How should we verify you?',
      subtitle:
          "Pick one — you'll confirm it with a one-time code in the next step.",
      content: Column(
        children: [
          SelectableMethodTile(
            selected: _verifyByPhone,
            icon: IconsaxPlusLinear.call,
            title: 'Phone number',
            subtitle: 'Code sent via SMS or WhatsApp',
            onTap: () => _selectVerificationMethod(phone: true),
          ),
          const SizedBox(height: 12),
          SelectableMethodTile(
            selected: !_verifyByPhone,
            icon: IconsaxPlusLinear.sms,
            title: 'Email address',
            subtitle: 'Code sent to your inbox',
            onTap: () => _selectVerificationMethod(phone: false),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: _verifyByPhone ? 'Phone number' : 'Email address',
            controller: _identifierController,
            focusNode: _identifierFocus,
            hintText: _verifyByPhone ? '0803 000 0000' : 'you@example.com',
            keyboardType: _verifyByPhone
                ? TextInputType.phone
                : TextInputType.emailAddress,
          ),
          if (_verifyByPhone) ...[
            const SizedBox(height: 10),
            _phoneChannelSelector(),
          ],
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading ? 'Sending code…' : 'Send code',
      onButtonPressed: () async {
        if (state.isLoading) return;
        final identifier = _identifierController.text;
        if (!_validIdentifier(identifier)) {
          _showMessage(
            _verifyByPhone
                ? 'Enter a valid Nigerian phone number.'
                : 'Enter a valid email address.',
          );
          return;
        }
        final notifier = ref.read(signupFlowProvider.notifier);
        if (_verifyByPhone) {
          await notifier.startPhone(identifier, _phoneChannel);
        } else {
          await notifier.startEmail(identifier);
        }
      },
    );
  }

  Widget _otpScreen() {
    final state = ref.watch(signupFlowProvider);
    final data = state.data;
    return _authPage(
      title: 'Enter the code',
      subtitle: "We sent a 6-digit code to verify it's really you.",
      content: Column(
        children: [
          Text(
            data?.identifier.isNotEmpty == true
                ? 'Sent to ${data!.identifier}'
                : 'Enter the code sent to your account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          PinInputField(pinCtrl: _otpController, isActive: !state.isLoading),
          const SizedBox(height: 10),
          OtpExpiryLabel(expiresAt: data?.otpExpiresAt),
          const SizedBox(height: 10),
          TestOtpBanner(flow: TestOtpFlow.signup, controller: _otpController),
          const SizedBox(height: 18),
          TextButton(
            onPressed: state.isLoading
                ? null
                : () async {
                    await ref.read(signupFlowProvider.notifier).resendOtp();
                    final latest = ref.read(signupFlowProvider);
                    if (latest.isDone) {
                      _showSuccessMessage(
                        latest.message ?? 'A new code was sent.',
                      );
                    }
                  },
            child: const Text("Didn't get it? Resend code"),
          ),
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading ? 'Verifying…' : 'Verify',
      onButtonPressed: () async {
        if (state.isLoading) return;
        if (validators.otp(_otpController.text) != null) {
          _showMessage('Enter the 6-digit code.');
          return;
        }
        await ref
            .read(signupFlowProvider.notifier)
            .verifyAccount(_otpController.text);
      },
    );
  }

  Widget _createPasswordScreen() {
    final state = ref.watch(signupFlowProvider);
    return _authPage(
      title: 'Create a password',
      subtitle:
          "This is the last signup step. You'll sign in after creating it.",
      content: Column(
        children: [
          Form(
            key: _createPasswordFormKey,
            child: Column(
              children: [
                AppPasswordField(
                  label: 'Password',
                  controller: _passwordController,
                  hintText: 'At least 8 characters',
                  validator: validators.isPasswordValid,
                  autovalidateMode: _createPasswordAutovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => refreshAuthFormState(() {}),
                ),
                const SizedBox(height: 14),
                AppPasswordField(
                  label: 'Confirm password',
                  controller: _confirmPasswordController,
                  hintText: 'Re-enter your password',
                  validator: (value) => validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  autovalidateMode: _createPasswordAutovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                PasswordStrengthWidget(password: _passwordController.text),
              ],
            ),
          ),
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading ? 'Creating password…' : 'Create password',
      onButtonPressed: () async {
        if (state.isLoading) return;
        final password = _passwordController.text;
        if (_createPasswordFormKey.currentState?.validate() != true) {
          refreshAuthFormState(() {
            _createPasswordAutovalidate = AutovalidateMode.onUserInteraction;
          });
          return;
        }
        await ref.read(signupFlowProvider.notifier).createPassword(password);
      },
    );
  }

  Widget _loginScreen() {
    final state = ref.watch(loginFlowProvider);
    final biometric = ref.watch(biometricLoginProvider);
    // Keep one shell while hydrating so the identifier field never flashes
    // before the remembered-account layout.
    if (biometric.phase == BiometricLoginPhase.hydrating) {
      return _authPage(
        title: 'Welcome back',
        subtitle: 'Checking this device…',
        showBack: false,
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        buttonLabel: 'Log in',
        onButtonPressed: () {},
      );
    }
    final remembered = biometric.profile;
    if (remembered != null) {
      return _rememberedLoginScreen(state, biometric, remembered);
    }
    return _authPage(
      title: 'Welcome back',
      subtitle: 'Log in with your registered email or phone and password.',
      showBack: false,
      content: Column(
        children: [
          AppTextField(
            label: 'Email or phone number',
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          AppPasswordField(
            label: 'Password',
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  _openAuthDestination(AuthDestination.passwordReset),
              child: const Text('Forgot password?'),
            ),
          ),
          if (biometric.message != null) _biometricMessage(biometric.message!),
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading ? 'Logging in…' : 'Log in',
      onButtonPressed: () async {
        if (state.isLoading) return;
        final identifier = _identifierController.text.trim();
        if (identifier.isEmpty || _passwordController.text.isEmpty) {
          _showMessage('Enter your email or phone number and password.');
          return;
        }
        await ref
            .read(loginFlowProvider.notifier)
            .login(identifier, _passwordController.text);
      },
      footer: TextButton(
        onPressed: () => _openAuthDestination(
          AuthDestination.verificationMethod,
          mode: AuthNavigationMode.clearStack,
        ),
        child: const Text('Create an account'),
      ),
    );
  }

  Widget _rememberedLoginScreen(
    NotifierState<LoginFlowData> state,
    BiometricLoginState biometric,
    RememberedBiometricProfile remembered,
  ) {
    final busy = state.isLoading || biometric.isBusy;
    final notifier = ref.read(biometricLoginProvider.notifier);
    final (biometricIcon, biometricLabel) = switch (biometric.presentation) {
      BiometricPresentation.faceId => (IconsaxPlusLinear.scan, 'Face ID'),
      BiometricPresentation.touchId => (
        IconsaxPlusLinear.finger_scan,
        'Touch ID',
      ),
      _ => (IconsaxPlusLinear.finger_scan, 'fingerprint'),
    };
    return _authPage(
      title: '${timeBasedGreeting(DateTime.now())}, ${remembered.firstName}',
      subtitle: 'Log in with your password or $biometricLabel.',
      showBack: false,
      content: Column(
        children: [
          AppPasswordField(
            label: 'Password',
            controller: _passwordController,
            autofillHints: const [AutofillHints.password],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: busy
                  ? null
                  : () {
                      notifier.cancelActiveOperation();
                      // Recovery clears the enrollment once it starts for
                      // this identifier.
                      _identifierController.text = remembered.identifier;
                      _openAuthDestination(AuthDestination.passwordReset);
                    },
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            button: true,
            label: 'Log in with $biometricLabel',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      FocusScope.of(context).unfocus();
                      await notifier.loginWithBiometrics();
                    },
              icon: Icon(biometricIcon),
              label: Text('Log in with $biometricLabel'),
            ),
          ),
          if (biometric.message != null) _biometricMessage(biometric.message!),
          _stateMessage(state),
        ],
      ),
      buttonLabel: busy ? 'Logging in…' : 'Log in',
      onButtonPressed: () async {
        if (busy) return;
        if (_passwordController.text.isEmpty) {
          _showMessage('Enter your password.');
          return;
        }
        await notifier.loginWithPassword(_passwordController.text);
      },
      footer: Semantics(
        button: true,
        label: 'Not ${remembered.firstName}? Sign in with another account',
        excludeSemantics: true,
        child: TextButton(
          onPressed: () async {
            notifier.cancelActiveOperation();
            ref.read(loginFlowProvider.notifier).cancel();
            _identifierController.clear();
            _passwordController.clear();
            await notifier.forgetEnrollment();
          },
          child: Text(
            'Not ${remembered.firstName}? Sign in with another account',
          ),
        ),
      ),
    );
  }

  Widget _biometricMessage(String message) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );

  Widget _passwordResetScreen() {
    final state = ref.watch(passwordRecoveryProvider);
    final stage = state.data?.stage ?? RecoveryFlowStage.idle;
    final awaitingOtp = stage == RecoveryFlowStage.awaitingOtp;
    final awaitingPassword = stage == RecoveryFlowStage.awaitingNewSecret;
    final title = awaitingOtp
        ? 'Verify your account'
        : awaitingPassword
        ? 'Choose a new password'
        : 'Reset your password';
    final subtitle = awaitingOtp
        ? 'Enter the 6-digit code sent to ${state.data?.identifier ?? ''}.'
        : awaitingPassword
        ? 'Use a strong password you have not used before.'
        : 'We will send a verification code to your email or phone.';

    Widget content;
    if (awaitingOtp) {
      content = Column(
        children: [
          PinInputField(pinCtrl: _otpController, isActive: !state.isLoading),
          const SizedBox(height: 10),
          OtpExpiryLabel(expiresAt: state.data?.otpExpiresAt),
          const SizedBox(height: 10),
          TestOtpBanner(
            flow: TestOtpFlow.passwordRecovery,
            controller: _otpController,
          ),
          _stateMessage(state),
        ],
      );
    } else if (awaitingPassword) {
      content = Column(
        children: [
          Form(
            key: _passwordResetFormKey,
            child: Column(
              children: [
                AppPasswordField(
                  label: 'New password',
                  controller: _passwordController,
                  validator: validators.isPasswordValid,
                  autovalidateMode: _passwordResetAutovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => refreshAuthFormState(() {}),
                ),
                const SizedBox(height: 14),
                AppPasswordField(
                  label: 'Confirm new password',
                  controller: _confirmPasswordController,
                  validator: (value) => validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  autovalidateMode: _passwordResetAutovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                PasswordStrengthWidget(password: _passwordController.text),
              ],
            ),
          ),
          _stateMessage(state),
        ],
      );
    } else {
      content = Column(
        children: [
          AppTextField(
            label: 'Email or phone number',
            controller: _identifierController,
          ),
          const SizedBox(height: 12),
          Text(
            'For phone numbers, choose where the code should be sent.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _phoneChannelSelector(),
          _stateMessage(state),
        ],
      );
    }

    return _authPage(
      title: title,
      subtitle: subtitle,
      content: content,
      buttonLabel: state.isLoading
          ? 'Please wait…'
          : awaitingOtp
          ? 'Verify code'
          : awaitingPassword
          ? 'Reset password'
          : 'Send code',
      onButtonPressed: () async {
        if (state.isLoading) return;
        final notifier = ref.read(passwordRecoveryProvider.notifier);
        if (awaitingOtp) {
          if (validators.otp(_otpController.text) != null) {
            _showMessage('Enter the 6-digit code.');
            return;
          }
          await notifier.verifyOtp(_otpController.text);
          return;
        }
        if (awaitingPassword) {
          if (_passwordResetFormKey.currentState?.validate() != true) {
            refreshAuthFormState(() {
              _passwordResetAutovalidate = AutovalidateMode.onUserInteraction;
            });
            return;
          }
          await notifier.reset(_passwordController.text);
          return;
        }
        final identifier = _identifierController.text.trim();
        if (identifier.isEmpty) {
          _showMessage('Enter your email or phone number.');
          return;
        }
        await notifier.start(
          identifier,
          channel: identifier.contains('@') ? null : _phoneChannel,
        );
      },
    );
  }

  Widget _newDeviceOtpScreen() {
    final state = ref.watch(loginFlowProvider);
    final data = state.data;
    final choosing = data?.stage == LoginFlowStage.choosingNewDeviceChannel;
    return _authPage(
      title: choosing ? 'Verify this device' : 'Enter the device code',
      subtitle: choosing
          ? 'Choose where we should send the security code.'
          : 'A 6-digit code was sent to ${data?.identifier ?? 'your account'}.',
      content: Column(
        children: [
          if (choosing)
            _phoneChannelSelector()
          else ...[
            PinInputField(pinCtrl: _otpController, isActive: !state.isLoading),
            const SizedBox(height: 10),
            OtpExpiryLabel(expiresAt: data?.otpExpiresAt),
            const SizedBox(height: 10),
            TestOtpBanner(
              flow: TestOtpFlow.newDeviceLogin,
              controller: _otpController,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : ref.read(loginFlowProvider.notifier).resendNewDeviceOtp,
              child: const Text('Resend code'),
            ),
          ],
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading
          ? 'Please wait…'
          : choosing
          ? 'Send code'
          : 'Verify device',
      onButtonPressed: () async {
        if (state.isLoading) return;
        final notifier = ref.read(loginFlowProvider.notifier);
        if (choosing) {
          await notifier.chooseNewDeviceChannel(_phoneChannel);
          return;
        }
        if (validators.otp(_otpController.text) != null) {
          _showMessage('Enter the 6-digit code.');
          return;
        }
        await notifier.verifyNewDevice(_otpController.text);
      },
    );
  }

  Widget _createFirstPinScreen() {
    final state = ref.watch(createFirstPinProvider);
    return _authPage(
      title: 'Create your transaction PIN',
      subtitle: 'Use this 4-digit PIN to authorize transactions.',
      showBack: false,
      content: Column(
        children: [
          const PinSecurityWarningBox(),
          const SizedBox(height: 18),
          Form(
            key: _createFirstPinFormKey,
            child: Column(
              children: [
                const Text('Enter PIN'),
                const SizedBox(height: 10),
                PinInputField(
                  pinLength: 4,
                  pinCtrl: _pinController,
                  obscureText: true,
                  isActive: !state.isLoading,
                  validator: validators.strongTransactionPin,
                  autoValidateMode: _createFirstPinAutovalidate,
                ),
                const SizedBox(height: 18),
                const Text('Confirm PIN'),
                const SizedBox(height: 10),
                PinInputField(
                  pinLength: 4,
                  pinCtrl: _confirmPinController,
                  obscureText: true,
                  isActive: !state.isLoading,
                  validator: (value) =>
                      value == _pinController.text ? null : 'PINs do not match',
                  autoValidateMode: _createFirstPinAutovalidate,
                ),
              ],
            ),
          ),
          _stateMessage(state),
        ],
      ),
      buttonLabel: state.isLoading ? 'Saving PIN…' : 'Create PIN',
      onButtonPressed: () async {
        if (state.isLoading) return;
        if (_createFirstPinFormKey.currentState?.validate() != true) {
          refreshAuthFormState(() {
            _createFirstPinAutovalidate = AutovalidateMode.onUserInteraction;
          });
          return;
        }
        await ref
            .read(createFirstPinProvider.notifier)
            .submit(_pinController.text);
      },
    );
  }
}
