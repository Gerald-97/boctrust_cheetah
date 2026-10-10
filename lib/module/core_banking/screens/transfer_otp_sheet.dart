import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';

/// Asks Core to send the transfer's OTP when the sheet opens, then collects
/// the six-digit code. [requestCode] returns why the code could not be sent,
/// or null.
///
/// Returns the code as typed, or null when the customer cancels. The caller
/// owns it only for the one finalize it authorizes and must not store it.
Future<String?> collectTransferOtp(
  BuildContext context, {
  required Future<String?> Function() requestCode,
}) => AppActionSheet.show<String>(
  context: context,
  builder: (_) => TransferOtpSheet(requestCode: requestCode),
);

const _otpLength = 6;

class TransferOtpSheet extends StatefulWidget {
  const TransferOtpSheet({required this.requestCode, super.key});

  final Future<String?> Function() requestCode;

  @override
  State<TransferOtpSheet> createState() => _TransferOtpSheetState();
}

class _TransferOtpSheetState extends State<TransferOtpSheet> {
  final _controller = TextEditingController();
  bool _sending = true;
  String? _error;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _request();
  }

  Future<void> _request() async {
    final error = await widget.requestCode();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
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
      !_sending &&
      _error == null &&
      RegExp('^\\d{$_otpLength}\$').hasMatch(_controller.text);

  void _close([String? code]) {
    if (_closing) return;
    _closing = true;
    _controller.clear();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error;
    return AppActionSheet(
      key: const Key('transfer-otp-sheet'),
      icon: IconsaxPlusLinear.message_text,
      title: 'Enter the code we sent you',
      subtitle: _sending
          ? 'Sending your code…'
          : 'Check your phone or email for a 6-digit code.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Verify code',
            onPressed: _complete && !_closing
                ? () => _close(_controller.text)
                : null,
          ),
          const SizedBox(height: BocSpace.xs),
          BocTextButton(label: 'Cancel', onPressed: _close),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(
            pinLength: _otpLength,
            pinCtrl: _controller,
            autofocus: true,
            isActive: !_closing && !_sending && error == null,
          ),
          if (error != null) ...[
            const SizedBox(height: BocSpace.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.bocColors.errorText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
