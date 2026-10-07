import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/core_submission_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'transaction_pin_sheet.dart';

/// Reserves an attempt for [draft], asks for the PIN and sends it once.
///
/// A rejected PIN reopens the sheet on the same attempt; closing the sheet
/// sends nothing. The PIN lives only in this call's local variable.
Future<void> authorizeAndSubmitTransfer(
  BuildContext context,
  WidgetRef ref, {
  required Object draft,
  required TransactionSummary summary,
}) async {
  final notifier = ref.read(coreTransferAttemptProvider.notifier);
  final id = notifier.beginReview(draft);
  if (id == null) {
    if (!ref.read(transferAuthorizationReadyProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfers are not available yet.')),
      );
    }
    return;
  }
  String? error;
  while (true) {
    final pin = await collectCoreTransactionPin(
      context,
      summary,
      errorMessage: error,
    );
    if (pin == null || !context.mounted) {
      notifier.cancelReview(id);
      return;
    }
    await notifier.submitAuthorized(id, pin);
    if (!context.mounted || !notifier.retryPin(id)) break;
    error = CoreRejection.wrongPin.message;
  }
  // Balances come from Core only; never subtract locally.
  unawaited(ref.read(customerBankAccountsProvider.notifier).load());
}

/// Every transfer screen shows the session's current attempt in place of its
/// own steps, so re-entering any transfer flow resumes it.
bool showsAttempt(CoreTransferAttempt? attempt) =>
    attempt != null && attempt.phase != CoreTransferPhase.authorizing;

/// The result of a sent transfer, whichever flow sent it.
class CoreTransferAttemptView extends ConsumerWidget {
  const CoreTransferAttemptView({
    required this.attempt,
    required this.onExit,
    required this.onEditDetails,
    required this.onStartDifferent,
    super.key,
  });

  final CoreTransferAttempt attempt;
  final VoidCallback onExit;

  /// Back to the form with its details kept, after a definite rejection.
  final VoidCallback onEditDetails;

  /// Back to an empty form, after an unresolved transfer is set aside.
  final VoidCallback onStartDifferent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (attempt.phase == CoreTransferPhase.submitting) {
      return const ApiLoadingSection(label: 'Sending your transfer');
    }
    final notifier = ref.read(coreTransferAttemptProvider.notifier);
    final (:amount, :details) = _describe(ref, attempt.draft);
    switch (attempt.outcome) {
      case RejectedSubmission(:final message):
        return TransactionResultView(
          kind: BocStatusKind.failed,
          title: 'Transfer declined',
          message: '$message No money has left your account.',
          amount: amount,
          details: details,
          primaryLabel: 'Change details',
          onPrimary: () {
            notifier.startNewTransfer();
            onEditDetails();
          },
          secondaryLabel: 'Close',
          onSecondary: () {
            notifier.startNewTransfer();
            onExit();
          },
        );
      case AcceptedSubmission(:final ack):
        final reference = ack.displayReference;
        return TransactionResultView(
          kind: BocStatusKind.pending,
          title: 'Transfer processing',
          message:
              "We're waiting for confirmation. Check your balance shortly "
              'before trying again.',
          amount: amount,
          details: [
            ...details,
            if (reference != null) (label: 'Reference', value: reference),
          ],
          extra: [
            ..._saveBeneficiary(ref),
            const SizedBox(height: BocSpace.sm),
            _startDifferent(context, ref),
          ],
          primaryLabel: 'Done',
          onPrimary: onExit,
        );
      case UnknownSubmission(:final message):
        return TransactionResultView(
          kind: BocStatusKind.pending,
          title: 'Transfer not confirmed',
          message: message,
          amount: amount,
          details: details,
          extra: [_startDifferent(context, ref)],
          primaryLabel: 'Done',
          onPrimary: onExit,
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  Widget _startDifferent(BuildContext context, WidgetRef ref) => BocTextButton(
    label: 'Start a different transfer',
    onPressed: () async {
      final start = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Start a different transfer?'),
          content: const Text(
            'This transfer may still go through. Check your balance first '
            '— sending it again could pay twice.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: const Text('Start anyway'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Check balance'),
            ),
          ],
        ),
      );
      if (start == null) return;
      if (!start) {
        unawaited(ref.read(customerBankAccountsProvider.notifier).load());
        onExit();
        return;
      }
      ref
          .read(coreTransferAttemptProvider.notifier)
          .acknowledgeUnresolved(attempt.id);
      onStartDifferent();
    },
  );

  List<Widget> _saveBeneficiary(WidgetRef ref) {
    final draft = attempt.draft;
    if (draft is! InterbankTransferDraft ||
        !ref
            .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
            .isAvailable) {
      return const [];
    }
    final saved = (ref.watch(beneficiariesProvider).data ?? const []).any(
      (b) => b.bankCode == draft.bankCode && b.number == draft.accountNumber,
    );
    if (saved) return const [];
    return [
      const SizedBox(height: BocSpace.md),
      SaveBeneficiaryButton(
        body: bankBeneficiaryRequest(
          bankCode: draft.bankCode,
          number: draft.accountNumber,
        ),
      ),
    ];
  }
}

/// Amount and receipt rows for any transfer draft.
({String? amount, List<({String label, String value})> details}) _describe(
  WidgetRef ref,
  Object draft,
) => switch (draft) {
  OwnAccountMoveDraft() => (
    amount: nairaFromKobo(draft.amountKobo),
    details: [
      (
        label: draft.direction == OwnAccountDirection.toSavings ? 'To' : 'From',
        value:
            ref
                .watch(customerBankAccountsProvider)
                .data
                ?.accounts
                .where((a) => a.productCode == draft.productCode)
                .firstOrNull
                ?.productName ??
            draft.productCode,
      ),
    ],
  ),
  BoctrustTransferDraft() => (
    amount: nairaFromKobo(draft.amountKobo),
    details: [
      (label: 'Bank', value: 'BOCTRUST'),
      (label: 'Account number', value: maskNumber(draft.toAccountNumber)),
    ],
  ),
  InterbankTransferDraft() => (
    amount: nairaFromKobo(draft.amountKobo),
    details: [
      (label: 'To', value: draft.accountName),
      (label: 'Bank', value: draft.bankName),
      (label: 'Account number', value: draft.accountNumber),
    ],
  ),
  _ => (amount: null, details: const []),
};
