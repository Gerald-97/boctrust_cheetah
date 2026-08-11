part of '../../app_flow/app_flow_navigator.dart';

extension OnboardingFlowScreens on AppFlowNavigatorState {
  Widget _onboardingScreen() {
    const slides = <({IconData icon, String title, String description})>[
      (
        icon: Icons.savings_outlined,
        title: 'Save without thinking about it',
        description:
            'Flex Save grows every day with no lock-in. Target, Lock and Group Save help you commit to a goal, on your terms.',
      ),
      (
        icon: Icons.track_changes_rounded,
        title: 'Reach any goal, your way',
        description:
            'Set a Target, lock in a fixed term for a higher rate, or save together with a Group — pick whichever fits.',
      ),
      (
        icon: Icons.send_rounded,
        title: 'Send and pay, instantly',
        description:
            'Move money between your BOCTrust accounts, send to friends and family, or pay bills — all in one place.',
      ),
    ];
    final slide = slides[_onboardingIndex];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _go(AppScreen.verifyMethod),
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
              const RegulatoryBadge(),
              const SizedBox(height: 14),
              PrimaryButton(
                label: _onboardingIndex == slides.length - 1
                    ? 'Get started'
                    : 'Next',
                onPressed: _advanceOnboarding,
              ),
              TextButton(
                onPressed: () => _go(AppScreen.login),
                child: const Text('I already have an account'),
              ),
            ],
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
  }) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                children: [
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
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(label: buttonLabel, onPressed: onButtonPressed),
                  if (footer != null) ...[const SizedBox(height: 10), footer],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifyMethodScreen() {
    return _authPage(
      title: 'How should we verify you?',
      subtitle:
          "Pick one — you'll confirm it with a one-time code in the next step.",
      content: Column(
        children: [
          SelectableMethodTile(
            selected: _verifyByPhone,
            icon: Icons.phone_outlined,
            title: 'Phone number',
            subtitle: 'Code sent via SMS or WhatsApp',
            onTap: () => _selectVerificationMethod(phone: true),
          ),
          const SizedBox(height: 12),
          SelectableMethodTile(
            selected: !_verifyByPhone,
            icon: Icons.mail_outline_rounded,
            title: 'Email address',
            subtitle: 'Code sent to your inbox',
            onTap: () => _selectVerificationMethod(phone: false),
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: _verifyByPhone ? 'Phone number' : 'Email address',
            initialValue: _verifyByPhone
                ? '+234 803 214 7756'
                : 'adaeze@example.com',
            keyboardType: _verifyByPhone
                ? TextInputType.phone
                : TextInputType.emailAddress,
          ),
          if (_verifyByPhone) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('SMS'),
                    selected: true,
                    onSelected: (_) {},
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('WhatsApp'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      buttonLabel: 'Send code',
      onButtonPressed: () => _go(AppScreen.otp),
    );
  }

  Widget _otpScreen() {
    return _authPage(
      title: 'Enter the code',
      subtitle: "We sent a 6-digit code to verify it's really you.",
      content: Column(
        children: [
          Text(
            _verifyByPhone
                ? 'Sent via SMS to +234 803 214 7756'
                : 'Sent to adaeze@example.com',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OtpBox(value: '4'),
              OtpBox(value: '2'),
              OtpBox(value: '8'),
              OtpBox(value: '1'),
              OtpBox(value: '•'),
              OtpBox(value: '•'),
            ],
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => _showMessage('A new verification code was sent.'),
            child: const Text("Didn't get it? Resend code · 0:42"),
          ),
        ],
      ),
      buttonLabel: 'Verify',
      onButtonPressed: () => _go(AppScreen.createPassword),
    );
  }

  Widget _createPasswordScreen() {
    return _authPage(
      title: 'Create a password',
      subtitle:
          "This is the last step before you're in — tier verification (BVN, NIN, address) happens later, inside the app.",
      content: const Column(
        children: [
          AppTextField(
            label: 'Password',
            hintText: 'Enter at least 8 characters',
            obscureText: true,
          ),
          SizedBox(height: 14),
          AppTextField(
            label: 'Confirm password',
            hintText: 'Re-enter your password',
            obscureText: true,
          ),
          SizedBox(height: 12),
          PasswordStrengthCard(),
        ],
      ),
      buttonLabel: 'Create account & continue',
      onButtonPressed: () => _go(AppScreen.home),
    );
  }

  Widget _loginScreen() {
    return _authPage(
      title: 'Welcome back',
      subtitle: 'Log in with your registered phone number and PIN.',
      content: Column(
        children: [
          const AppTextField(
            label: 'Phone number',
            initialValue: '+234 803 214 7756',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 18),
          Text(
            'Enter your 4-digit PIN',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          const PinDots(filled: 4),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _showMessage('Face ID authentication requested.'),
            icon: const Icon(Icons.face_rounded),
            label: const Text('Use Face ID instead'),
          ),
          TextButton(
            onPressed: () => _showMessage('PIN reset flow opened.'),
            child: const Text('Forgot PIN? Reset it'),
          ),
        ],
      ),
      buttonLabel: 'Log in',
      onButtonPressed: () => _go(AppScreen.home),
    );
  }
}
