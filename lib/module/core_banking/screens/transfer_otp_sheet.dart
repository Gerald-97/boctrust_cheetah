import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../provider/core_transfer_attempt_provider.dart';

/// Collects the six-digit OTP Core sent when the PIN was verified, and
/// verifies it in place. [verifyCode] and [resendCode] go straight to the
/// attempt; the code is never returned or kept.
///
/// Returns true once the code is verified, false when the customer cancels
/// or the attempt stops.
Future<bool> collectTransferOtp(
  BuildContext context, {
  required Future<CheckStep> Function(String code) verifyCode,
  required Future<CheckStep> Function() resendCode,
}) async =>
    await AppActionSheet.show<bool>(
      context: context,
      builder: (_) =>
          TransferOtpSheet(verifyCode: verifyCode, resendCode: resendCode),
    ) ??
    false;

const _otpLength = 6;

class TransferOtpSheet extends StatefulWidget {
  const TransferOtpSheet({
    required this.verifyCode,
    required this.resendCode,
    super.key,
  });

  final Future<CheckStep> Function(String code) verifyCode;
  final Future<CheckStep> Function() resendCode;

  @override
  State<TransferOtpSheet> createState() => _TransferOtpSheetState();
}

class _TransferOtpSheetState extends State<TransferOtpSheet> {
  final _controller = TextEditingController();
  bool _verifying = false;
  bool _resending = false;
  bool _closing = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..clear()
      ..dispose();
    super.dispose();
  }

  bool get _complete =>
      !_verifying &&
      !_closing &&
      RegExp('^\\d{$_otpLength}\$').hasMatch(_controller.text);

  void _close(bool verified) {
    if (_closing) return;
    _closing = true;
    _controller.clear();
    Navigator.of(context).pop(verified);
  }

  Future<void> _verify() async {
    if (!_complete) return;
    final code = _controller.text;
    setState(() {
      _verifying = true;
      _error = null;
      _notice = null;
    });
    final step = await widget.verifyCode(code);
    if (!mounted) return;
    switch (step) {
      case CheckPassed():
        _close(true);
      case CheckStopped():
        _close(false);
      case CheckRetry(:final message):
        _controller.clear();
        setState(() {
          _verifying = false;
          _error = message;
        });
    }
  }

  Future<void> _resend() async {
    if (_resending || _verifying || _closing) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    final step = await widget.resendCode();
    if (!mounted) return;
    switch (step) {
      case CheckPassed():
        setState(() {
          _resending = false;
          _notice = 'We sent you a new code.';
        });
      case CheckStopped():
        _close(false);
      case CheckRetry(:final message):
        setState(() {
          _resending = false;
          _error = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _error ?? _notice;
    return AppActionSheet(
      key: const Key('transfer-otp-sheet'),
      icon: IconsaxPlusLinear.message_text,
      title: 'Enter the code we sent you',
      subtitle: 'Check your phone or email for a 6-digit code.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Verify code',
            isLoading: _verifying,
            onPressed: _complete ? _verify : null,
          ),
          const SizedBox(height: BocSpace.xs),
          BocTextButton(
            label: 'Resend code',
            isLoading: _resending,
            onPressed: _resending || _verifying ? null : _resend,
          ),
          BocTextButton(label: 'Cancel', onPressed: () => _close(false)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(
            pinLength: _otpLength,
            pinCtrl: _controller,
            autofocus: true,
            isActive: !_closing && !_verifying,
          ),
          if (message != null) ...[
            const SizedBox(height: BocSpace.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _error != null ? context.bocColors.errorText : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
