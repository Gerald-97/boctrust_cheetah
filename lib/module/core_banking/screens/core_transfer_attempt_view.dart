import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'transaction_pin_sheet.dart';
import 'transfer_otp_sheet.dart';

/// Starts the reviewed [draft]: initiate, then the PIN sheet, then (only
/// when Core asks) the OTP page, then one finalize.
///
/// Closing either sheet sends nothing and releases the attempt. A rejected
/// PIN or OTP reopens the PIN sheet on the same initiation. The PIN and OTP
/// live only in this call's local variables.
Future<void> authorizeStagedTransfer(
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
  await notifier.initiate(id);
  String? error;
  while (true) {
    final attempt = ref.read(coreTransferAttemptProvider).current;
    final initiation = attempt?.initiation;
    if (attempt?.id != id ||
        attempt?.phase != CoreTransferPhase.awaitingChecks ||
        initiation == null ||
        !context.mounted) {
      return;
    }
    final pin = await collectCoreTransactionPin(
      context,
      summary,
      errorMessage: error,
    );
    if (pin == null || !context.mounted) {
      notifier.cancelReview(id);
      return;
    }
    String? otp;
    if (initiation.needsOtp) {
      otp = await collectTransferOtp(
        context,
        requestCode: () => notifier.requestOtp(id),
      );
      if (otp == null || !context.mounted) {
        notifier.cancelReview(id);
        return;
      }
    }
    await notifier.finalize(id, pin: pin, otp: otp);
    if (!context.mounted || !notifier.retryPin(id)) break;
    error = CoreRejection.wrongPin.message;
  }
  // Balances come from Core only; never subtract locally.
  unawaited(ref.read(customerBankAccountsProvider.notifier).load());
}

/// Every transfer screen shows the session's current attempt in place of its
/// own steps, so re-entering any transfer flow resumes it.
bool showsAttempt(CoreTransferAttempt? attempt) =>
    attempt != null && attempt.phase != CoreTransferPhase.awaitingChecks;

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
    switch (attempt.phase) {
      case CoreTransferPhase.initiating:
        return const ApiLoadingSection(label: 'Starting your transfer');
      case CoreTransferPhase.finalizing:
        return const ApiLoadingSection(label: 'Sending your transfer');
      case CoreTransferPhase.awaitingChecks || CoreTransferPhase.settled:
        break;
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
        final (kind, title, message) = switch (attempt.live?.state) {
          CoreLiveState.completed => (
            BocStatusKind.success,
            'Transfer successful',
            'Your balance will update shortly.',
          ),
          CoreLiveState.failed => (
            BocStatusKind.failed,
            'Transfer failed',
            'This transfer did not go through. If your balance changed, '
                'contact support with the reference below.',
          ),
          CoreLiveState.reversed => (
            BocStatusKind.failed,
            'Transfer reversed',
            'This transfer was reversed and the money returned to your '
                'account.',
          ),
          CoreLiveState.unknown => (
            BocStatusKind.pending,
            'Transfer not confirmed',
            "We couldn't confirm this transfer. Check your balance before "
                'trying again.',
          ),
          CoreLiveState.pending || null => (
            BocStatusKind.pending,
            'Transfer processing',
            "We're waiting for confirmation. Check your balance shortly "
                'before trying again.',
          ),
        };
        return TransactionResultView(
          kind: kind,
          title: title,
          message: message,
          amount: amount,
          details: [
            ...details,
            if (reference != null) (label: 'Reference', value: reference),
          ],
          extra: [
            ..._checkStatus(ref),
            ..._saveBeneficiary(ref),
            if (attempt.unresolved) ...[
              const SizedBox(height: BocSpace.sm),
              _startDifferent(context, ref),
            ],
          ],
          primaryLabel: 'Done',
          onPrimary: () {
            notifier.startNewTransfer();
            onExit();
          },
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

  /// Check status while the outcome is open; nothing without a tracking
  /// reference, which is never substituted by a receipt reference.
  List<Widget> _checkStatus(WidgetRef ref) {
    if (!attempt.unresolved) return const [];
    if (attempt.tracking == null) {
      return const [
        SizedBox(height: BocSpace.md),
        ApiStateCard(
          title: 'Status unavailable',
          message:
              'No tracking reference was returned, so this transfer cannot '
              'be checked here. Check your balance shortly.',
          tone: ApiStateTone.info,
        ),
      ];
    }
    final error = attempt.checkError;
    return [
      const SizedBox(height: BocSpace.md),
      if (error != null) FieldError(error),
      SecondaryButton(
        label: attempt.checking
            ? 'Checking…'
            : attempt.live == null && error == null
            ? 'Check status'
            : 'Check again',
        onPressed: attempt.checking
            ? null
            : () => ref
                  .read(coreTransferAttemptProvider.notifier)
                  .check(attempt.id),
      ),
    ];
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

/// Transfers the customer set aside while unresolved, shown above each
/// transfer form so they stay visible and can still be checked.
class SetAsideTransfers extends ConsumerWidget {
  const SetAsideTransfers({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts = ref.watch(coreTransferAttemptProvider).acknowledged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final attempt in attempts)
          Padding(
            padding: const EdgeInsets.only(bottom: BocSpace.sm),
            child: ApiStateCard(
              title: switch (attempt.live?.state) {
                CoreLiveState.completed => 'Earlier transfer successful',
                CoreLiveState.failed => 'Earlier transfer failed',
                CoreLiveState.reversed => 'Earlier transfer reversed',
                _ => 'Earlier transfer not confirmed',
              },
              message: [
                _describe(ref, attempt.draft).amount ?? '',
                ?attempt.checkError,
              ].where((line) => line.isNotEmpty).join(' · '),
              tone: attempt.unresolved
                  ? ApiStateTone.warning
                  : ApiStateTone.info,
              actionLabel: attempt.unresolved && attempt.tracking != null
                  ? (attempt.checking ? 'Checking…' : 'Check status')
                  : null,
              onAction: attempt.checking
                  ? null
                  : () => ref
                        .read(coreTransferAttemptProvider.notifier)
                        .check(attempt.id),
            ),
          ),
      ],
    );
  }
}

/// Amount and receipt rows for any transfer draft.
({String? amount, List<({String label, String value})> details}) _describe(
  WidgetRef ref,
  Object draft,
) => switch (draft) {
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
