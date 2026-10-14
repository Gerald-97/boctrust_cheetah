import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../service/transaction_authorizer.dart';

/// Asks for the customer's four-digit transaction PIN for [summary].
///
/// Returns the PIN exactly as typed (leading zeros kept), or null when the
/// customer cancels or dismisses the sheet. The caller owns the string only
/// for the one submission it authorizes and must not store it. [errorMessage]
/// is safe copy from a previous attempt, such as a rejected PIN.
///
/// [confirmLabel] names what the PIN does: "Confirm transfer" when it is the
/// last check, "Verify PIN" when an OTP follows.
Future<String?> collectCoreTransactionPin(
  BuildContext context,
  TransactionSummary summary, {
  String? errorMessage,
  String confirmLabel = 'Confirm transfer',
}) => AppActionSheet.show<String>(
  context: context,
  builder: (_) => TransactionPinSheet(
    summary: summary,
    errorMessage: errorMessage,
    confirmLabel: confirmLabel,
  ),
);

const _pinLength = 4;

class TransactionPinSheet extends StatefulWidget {
  const TransactionPinSheet({
    required this.summary,
    this.errorMessage,
    this.confirmLabel = 'Confirm transfer',
    super.key,
  });

  final TransactionSummary summary;
  final String? errorMessage;
  final String confirmLabel;

  @override
  State<TransactionPinSheet> createState() => _TransactionPinSheetState();
}

class _TransactionPinSheetState extends State<TransactionPinSheet> {
  final _controller = TextEditingController();
  bool _closing = false;

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
      RegExp('^\\d{$_pinLength}\$').hasMatch(_controller.text);

  void _confirm() {
    if (_closing || !_complete) return;
    _closing = true;
    final pin = _controller.text;
    // Empty the field before the sheet animates away so the digits do not
    // linger in the widget tree.
    _controller.clear();
    Navigator.of(context).pop(pin);
  }

  void _cancel() {
    if (_closing) return;
    _closing = true;
    _controller.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final error = widget.errorMessage;
    return AppActionSheet(
      key: const Key('transaction-pin-sheet'),
      icon: IconsaxPlusLinear.lock_1,
      title: 'Enter your transaction PIN',
      subtitle: summary.title,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: widget.confirmLabel,
            onPressed: _complete && !_closing ? _confirm : null,
          ),
          const SizedBox(height: BocSpace.xs),
          BocTextButton(label: 'Cancel', onPressed: _cancel),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            summary.amountDisplay,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          for (final (label, value) in summary.lines)
            Padding(
              padding: const EdgeInsets.only(top: BocSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  const SizedBox(width: BocSpace.md),
                  Expanded(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: BocSpace.lg),
          PinInputField(
            pinLength: _pinLength,
            pinCtrl: _controller,
            obscureText: true,
            autofocus: true,
            isActive: !_closing,
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
