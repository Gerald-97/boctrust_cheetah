import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/response_handler.dart';
import '../../../utils/auth_input.dart';
import '../../../utils/validators.dart' as validators;
import '../../app_flow/app_ui.dart';
import '../../component/password_strength_component.dart';
import '../../component/text_fields.dart';
import '../model/auth_enums.dart';
import '../provider/signup_flow_provider.dart';
import '../provider/test_otp_provider.dart';
import 'auth_widgets.dart';

/// Chooses phone or email and sends the sign-up code.
class VerifyMethodScreen extends ConsumerStatefulWidget {
  const VerifyMethodScreen({super.key});

  @override
  ConsumerState<VerifyMethodScreen> createState() => _VerifyMethodScreenState();
}

class _VerifyMethodScreenState extends ConsumerState<VerifyMethodScreen> {
  final _identifierController = TextEditingController();
  final _identifierFocus = FocusNode();
  bool _byPhone = true;
  PhoneVerificationChannel _channel = PhoneVerificationChannel.sms;

  @override
  void dispose() {
    _identifierController.dispose();
    _identifierFocus.dispose();
    super.dispose();
  }

  void _selectMethod({required bool phone}) {
    if (phone == _byPhone) return;
    final wasTyping = _identifierFocus.hasFocus;
    setState(() {
      _byPhone = phone;
      _identifierController.clear();
    });
    // An open soft keyboard keeps its layout when keyboardType changes (on
    // Android the IME is not restarted). Dropping focus closes the input
    // connection; restoring it next frame reopens the keyboard as the new
    // type, so choosing email shows the email keyboard.
    if (wasTyping) {
      _identifierFocus.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _identifierFocus.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupFlowProvider);
    return AuthBackScope(
      fallback: AuthDestination.login,
      builder: (context, onBack) => AuthPage(
        title: 'How should we verify you?',
        subtitle:
            "Pick one — you'll confirm it with a one-time code in the next step.",
        onBack: onBack,
        content: Column(
          children: [
            SelectableMethodTile(
              selected: _byPhone,
              icon: IconsaxPlusLinear.call,
              title: 'Phone number',
              subtitle: 'Code sent via SMS or WhatsApp',
              onTap: () => _selectMethod(phone: true),
            ),
            const SizedBox(height: 12),
            SelectableMethodTile(
              selected: !_byPhone,
              icon: IconsaxPlusLinear.sms,
              title: 'Email address',
              subtitle: 'Code sent to your inbox',
              onTap: () => _selectMethod(phone: false),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: _byPhone ? 'Phone number' : 'Email address',
              controller: _identifierController,
              focusNode: _identifierFocus,
              hintText: _byPhone ? '0803 000 0000' : 'you@example.com',
              keyboardType: _byPhone
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
            ),
            if (_byPhone) ...[
              const SizedBox(height: 10),
              PhoneChannelSelector(
                value: _channel,
                onChanged: (channel) => setState(() => _channel = channel),
              ),
            ],
            AuthStateMessage(state),
          ],
        ),
        buttonLabel: 'Send code',
        isLoading: state.isLoading,
        footer: const AuthLegalNotice(),
        onButtonPressed: () async {
          if (state.isLoading) return;
          final identifier = _identifierController.text;
          final valid = _byPhone
              ? isValidNigerianPhone(identifier)
              : validators.isEmail(identifier);
          if (!valid) {
            ResponseHandler.showInfo(
              _byPhone
                  ? 'Enter a valid Nigerian phone number.'
                  : 'Enter a valid email address.',
            );
            return;
          }
          final notifier = ref.read(signupFlowProvider.notifier);
          if (_byPhone) {
            await notifier.startPhone(identifier, _channel);
          } else {
            await notifier.startEmail(identifier);
          }
        },
      ),
    );
  }
}

/// Confirms the sign-up code.
class SignupOtpScreen extends ConsumerStatefulWidget {
  const SignupOtpScreen({super.key});

  @override
  ConsumerState<SignupOtpScreen> createState() => _SignupOtpScreenState();
}

class _SignupOtpScreenState extends ConsumerState<SignupOtpScreen> {
  final _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupFlowProvider);
    final data = state.data;
    return AuthBackScope(
      fallback: AuthDestination.verificationMethod,
      builder: (context, onBack) => AuthPage(
        title: 'Enter the code',
        subtitle: "We sent a 6-digit code to verify it's really you.",
        onBack: onBack,
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
                        ResponseHandler.showSuccess(
                          latest.message ?? 'A new code was sent.',
                        );
                      }
                    },
              child: const Text("Didn't get it? Resend code"),
            ),
            AuthStateMessage(state),
          ],
        ),
        buttonLabel: 'Verify',
        isLoading: state.isLoading,
        onButtonPressed: () async {
          if (state.isLoading) return;
          if (validators.otp(_otpController.text) != null) {
            ResponseHandler.showInfo('Enter the 6-digit code.');
            return;
          }
          await ref
              .read(signupFlowProvider.notifier)
              .verifyAccount(_otpController.text);
        },
      ),
    );
  }
}

/// The last sign-up step.
class CreatePasswordScreen extends ConsumerStatefulWidget {
  const CreatePasswordScreen({super.key});

  @override
  ConsumerState<CreatePasswordScreen> createState() =>
      _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends ConsumerState<CreatePasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signupFlowProvider);
    return AuthBackScope(
      fallback: AuthDestination.verificationMethod,
      builder: (context, onBack) => AuthPage(
        title: 'Create a password',
        subtitle:
            "This is the last signup step. You'll sign in after creating it.",
        onBack: onBack,
        content: Column(
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  AppPasswordField(
                    label: 'Password',
                    controller: _passwordController,
                    hintText: 'At least 8 characters',
                    validator: validators.isPasswordValid,
                    autovalidateMode: _autovalidate,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  AppPasswordField(
                    label: 'Confirm password',
                    controller: _confirmController,
                    hintText: 'Re-enter your password',
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
        ),
        buttonLabel: 'Create password',
        isLoading: state.isLoading,
        onButtonPressed: () async {
          if (state.isLoading) return;
          final password = _passwordController.text;
          if (_formKey.currentState?.validate() != true) {
            setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
            return;
          }
          await ref.read(signupFlowProvider.notifier).createPassword(password);
        },
      ),
    );
  }
}
