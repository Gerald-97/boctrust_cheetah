import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../onboarding/model/remembered_biometric_profile.dart';
import '../service/transaction_authorizer.dart';

/// What the customer chose on the biometric approval sheet.
enum BiometricApprovalChoice {
  /// Approve with the device biometric and the saved PIN.
  approve,

  /// Enter the transaction PIN instead.
  usePin,
}

/// Asks the customer to approve [summary] with [presentation]'s biometric.
///
/// Returns the choice, or null when the customer dismisses the sheet. The
/// sheet never sees the PIN and never prompts by itself: the caller runs the
/// biometric approval after it closes. [title] names what is approved, such
/// as "Confirm transfer" or "Confirm payment". [errorMessage] is safe copy
/// from a previous try, such as an unrecognized biometric.
Future<BiometricApprovalChoice?> collectBiometricApproval(
  BuildContext context,
  TransactionSummary summary, {
  required BiometricPresentation? presentation,
  String title = 'Confirm transfer',
  String? errorMessage,
}) => AppActionSheet.show<BiometricApprovalChoice>(
  context: context,
  builder: (_) => BiometricApprovalSheet(
    summary: summary,
    presentation: presentation,
    title: title,
    errorMessage: errorMessage,
  ),
);

class BiometricApprovalSheet extends StatefulWidget {
  const BiometricApprovalSheet({
    required this.summary,
    required this.presentation,
    this.title = 'Confirm transfer',
    this.errorMessage,
    super.key,
  });

  final TransactionSummary summary;
  final BiometricPresentation? presentation;
  final String title;
  final String? errorMessage;

  @override
  State<BiometricApprovalSheet> createState() => _BiometricApprovalSheetState();
}

class _BiometricApprovalSheetState extends State<BiometricApprovalSheet> {
  bool _closing = false;

  /// Closes once: a second tap during the exit animation must not pop the
  /// screen underneath.
  void _close(BiometricApprovalChoice choice) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(choice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    final error = widget.errorMessage;
    final (icon, label) = switch (widget.presentation) {
      BiometricPresentation.faceId => (IconsaxPlusLinear.scan, 'Face ID'),
      BiometricPresentation.touchId => (
        IconsaxPlusLinear.finger_scan,
        'Touch ID',
      ),
      _ => (IconsaxPlusLinear.finger_scan, 'fingerprint'),
    };
    return AppActionSheet(
      key: const Key('biometric-approval-sheet'),
      icon: icon,
      title: widget.title,
      subtitle: summary.title,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Use $label',
            onPressed: () => _close(BiometricApprovalChoice.approve),
          ),
          const SizedBox(height: BocSpace.xs),
          BocTextButton(
            label: 'Use PIN instead',
            onPressed: () => _close(BiometricApprovalChoice.usePin),
          ),
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
          if (error != null) ...[
            const SizedBox(height: BocSpace.lg),
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
