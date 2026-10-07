import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/response_handler.dart';
import '../../../app/services.dart';
import '../../../utils/utils.dart';
import '../../../utils/validators.dart' as validators;
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/remembered_biometric_profile.dart';
import '../provider/biometric_login_provider.dart';
import '../provider/login_flow_provider.dart';
import '../provider/test_otp_provider.dart';
import 'auth_widgets.dart';

/// Password sign-in, or the remembered-account layout when this device has a
/// biometric enrollment.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openPasswordReset() =>
      openAuthDestination(ref, AuthDestination.passwordReset);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginFlowProvider);
    final biometric = ref.watch(biometricLoginProvider);
    return AuthBackScope(
      exitsApp: true,
      builder: (context, _) {
        // Keep one shell while hydrating so the identifier field never
        // flashes before the remembered-account layout.
        if (biometric.phase == BiometricLoginPhase.hydrating) {
          return AuthPage(
            title: 'Welcome back',
            subtitle: 'Checking this device…',
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
          return _remembered(state, biometric, remembered);
        }
        return AuthPage(
          title: 'Welcome back',
          subtitle: 'Log in with your registered email or phone and password.',
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
                  onPressed: _openPasswordReset,
                  child: const Text('Forgot password?'),
                ),
              ),
              if (biometric.message != null)
                _BiometricMessage(biometric.message!),
              AuthStateMessage(state),
            ],
          ),
          buttonLabel: state.isLoading ? 'Logging in…' : 'Log in',
          onButtonPressed: () async {
            if (state.isLoading) return;
            final identifier = _identifierController.text.trim();
            if (identifier.isEmpty || _passwordController.text.isEmpty) {
              ResponseHandler.showInfo(
                'Enter your email or phone number and password.',
              );
              return;
            }
            await ref
                .read(loginFlowProvider.notifier)
                .login(identifier, _passwordController.text);
          },
          footer: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => openAuthDestination(
                  ref,
                  AuthDestination.verificationMethod,
                  mode: AuthNavigationMode.clearStack,
                ),
                child: const Text('Create an account'),
              ),
              const SizedBox(height: 4),
              const AuthLegalNotice(),
            ],
          ),
        );
      },
    );
  }

  Widget _remembered(
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
    return AuthPage(
      title: '${timeBasedGreeting(DateTime.now())}, ${remembered.firstName}',
      subtitle: 'Log in with your password or $biometricLabel.',
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
                      _openPasswordReset();
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
          if (biometric.message != null) _BiometricMessage(biometric.message!),
          AuthStateMessage(state),
        ],
      ),
      buttonLabel: busy ? 'Logging in…' : 'Log in',
      onButtonPressed: () async {
        if (busy) return;
        if (_passwordController.text.isEmpty) {
          ResponseHandler.showInfo('Enter your password.');
          return;
        }
        await notifier.loginWithPassword(_passwordController.text);
      },
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
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
          const SizedBox(height: 4),
          const AuthLegalNotice(),
        ],
      ),
    );
  }
}

class _BiometricMessage extends StatelessWidget {
  const _BiometricMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// Verifies an unrecognised device during sign-in.
class NewDeviceOtpScreen extends ConsumerStatefulWidget {
  const NewDeviceOtpScreen({super.key});

  @override
  ConsumerState<NewDeviceOtpScreen> createState() => _NewDeviceOtpScreenState();
}

class _NewDeviceOtpScreenState extends ConsumerState<NewDeviceOtpScreen> {
  final _otpController = TextEditingController();
  PhoneVerificationChannel _channel = PhoneVerificationChannel.sms;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Leaving before sign-in completes abandons the attempt.
  void _cancelAttempt() {
    if (ref.read(loginFlowProvider).data?.stage != LoginFlowStage.completed) {
      ref.read(loginFlowProvider.notifier).cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginFlowProvider);
    final data = state.data;
    final choosing = data?.stage == LoginFlowStage.choosingNewDeviceChannel;
    return AuthBackScope(
      onLeave: _cancelAttempt,
      builder: (context, onBack) => AuthPage(
        title: choosing ? 'Verify this device' : 'Enter the device code',
        subtitle: choosing
            ? 'Choose where we should send the security code.'
            : 'A 6-digit code was sent to ${data?.identifier ?? 'your account'}.',
        onBack: onBack,
        content: Column(
          children: [
            if (choosing)
              PhoneChannelSelector(
                value: _channel,
                onChanged: (channel) => setState(() => _channel = channel),
              )
            else ...[
              PinInputField(
                pinCtrl: _otpController,
                isActive: !state.isLoading,
              ),
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
            AuthStateMessage(state),
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
            await notifier.chooseNewDeviceChannel(_channel);
            return;
          }
          if (validators.otp(_otpController.text) != null) {
            ResponseHandler.showInfo('Enter the 6-digit code.');
            return;
          }
          await notifier.verifyNewDevice(_otpController.text);
        },
      ),
    );
  }
}
