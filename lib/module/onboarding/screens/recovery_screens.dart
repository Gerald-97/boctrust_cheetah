import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/response_handler.dart';
import '../../../utils/validators.dart' as validators;
import '../../app_flow/app_ui.dart';
import '../../component/password_strength_component.dart';
import '../../component/text_fields.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../provider/recovery_providers.dart';
import '../provider/security_action_providers.dart';
import '../provider/test_otp_provider.dart';
import 'auth_widgets.dart';

/// Password recovery: identifier, then code, then the new password, all on
/// one route.
class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  PhoneVerificationChannel _channel = PhoneVerificationChannel.sms;

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    final Widget content;
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
          AuthStateMessage(state),
        ],
      );
    } else if (awaitingPassword) {
      content = Column(
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppPasswordField(
                  label: 'New password',
                  controller: _passwordController,
                  validator: validators.isPasswordValid,
                  autovalidateMode: _autovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                AppPasswordField(
                  label: 'Confirm new password',
                  controller: _confirmController,
                  validator: (value) => validators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                  autovalidateMode: _autovalidate,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                PasswordStrengthWidget(password: _passwordController.text),
              ],
            ),
          ),
          AuthStateMessage(state),
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
          PhoneChannelSelector(
            value: _channel,
            onChanged: (channel) => setState(() => _channel = channel),
          ),
          AuthStateMessage(state),
        ],
      );
    }

    return AuthBackScope(
      fallback: AuthDestination.login,
      onLeave: ref.read(passwordRecoveryProvider.notifier).cancel,
      builder: (context, onBack) => AuthPage(
        title: title,
        subtitle: subtitle,
        onBack: onBack,
        content: content,
        buttonLabel: awaitingOtp
            ? 'Verify code'
            : awaitingPassword
            ? 'Reset password'
            : 'Send code',
        isLoading: state.isLoading,
        onButtonPressed: () async {
          if (state.isLoading) return;
          final notifier = ref.read(passwordRecoveryProvider.notifier);
          if (awaitingOtp) {
            if (validators.otp(_otpController.text) != null) {
              ResponseHandler.showInfo('Enter the 6-digit code.');
              return;
            }
            await notifier.verifyOtp(_otpController.text);
            return;
          }
          if (awaitingPassword) {
            if (_formKey.currentState?.validate() != true) {
              setState(
                () => _autovalidate = AutovalidateMode.onUserInteraction,
              );
              return;
            }
            await notifier.reset(_passwordController.text);
            return;
          }
          final identifier = _identifierController.text.trim();
          if (identifier.isEmpty) {
            ResponseHandler.showInfo('Enter your email or phone number.');
            return;
          }
          await notifier.start(
            identifier,
            channel: identifier.contains('@') ? null : _channel,
          );
        },
      ),
    );
  }
}

/// Sets the transaction PIN right after the first sign-in.
class CreateFirstPinScreen extends ConsumerStatefulWidget {
  const CreateFirstPinScreen({super.key});

  @override
  ConsumerState<CreateFirstPinScreen> createState() =>
      _CreateFirstPinScreenState();
}

class _CreateFirstPinScreenState extends ConsumerState<CreateFirstPinScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createFirstPinProvider);
    return AuthBackScope(
      builder: (context, _) => AuthPage(
        title: 'Create your transaction PIN',
        subtitle: 'Use this 4-digit PIN to authorize transactions.',
        content: Column(
          children: [
            const PinSecurityWarningBox(),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
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
                    autoValidateMode: _autovalidate,
                  ),
                  const SizedBox(height: 18),
                  const Text('Confirm PIN'),
                  const SizedBox(height: 10),
                  PinInputField(
                    pinLength: 4,
                    pinCtrl: _confirmPinController,
                    obscureText: true,
                    isActive: !state.isLoading,
                    validator: (value) => value == _pinController.text
                        ? null
                        : 'PINs do not match',
                    autoValidateMode: _autovalidate,
                  ),
                ],
              ),
            ),
            AuthStateMessage(state),
          ],
        ),
        buttonLabel: 'Create PIN',
        isLoading: state.isLoading,
        onButtonPressed: () async {
          if (state.isLoading) return;
          if (_formKey.currentState?.validate() != true) {
            setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
            return;
          }
          await ref
              .read(createFirstPinProvider.notifier)
              .submit(_pinController.text);
        },
      ),
    );
  }
}
