import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_money.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'core_transfer_attempt_view.dart';

enum _Step { form, review }

final _tenDigits = RegExp(r'^\d{10}$');

/// Sends money from BocFlex to another BOCTRUST customer.
///
/// Core publishes no name lookup for BOCTRUST accounts, so review shows the
/// masked number and an irreversibility warning instead of a name.
class BoctrustTransferFlow extends ConsumerStatefulWidget {
  const BoctrustTransferFlow({
    required this.onExit,
    required this.onSectionSelected,
    super.key,
  });

  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<BoctrustTransferFlow> createState() =>
      _BoctrustTransferFlowState();
}

class _BoctrustTransferFlowState extends ConsumerState<BoctrustTransferFlow> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  _Step _step = _Step.form;
  BoctrustTransferDraft? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(customerBankAccountsProvider.notifier).ensureLoaded());
    });
  }

  @override
  void dispose() {
    for (final controller in [_account, _amount, _narration]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _edit() => setState(() {
    _draft = null;
    _step = _Step.form;
  });

  /// An empty form, after an unresolved transfer is set aside.
  void _startDifferent() => setState(() {
    for (final controller in [_account, _amount, _narration]) {
      controller.clear();
    }
    _draft = null;
    _step = _Step.form;
  });

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(coreTransferAttemptProvider).current;
    final accountsState = ref.watch(customerBankAccountsProvider);
    final accounts = accountsState.data;
    final flex = accounts?.activeFlexAccount;
    return AppScaffold(
      title: 'To a BOCTRUST account',
      activeSection: AppSection.send,
      onBack: _step == _Step.review && !showsAttempt(attempt)
          ? () => setState(() => _step = _Step.form)
          : widget.onExit,
      onSectionSelected: widget.onSectionSelected,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          if (!showsAttempt(attempt)) const SetAsideTransfers(),
          if (showsAttempt(attempt))
            CoreTransferAttemptView(
              attempt: attempt!,
              onExit: widget.onExit,
              onEditDetails: () => setState(() => _step = _Step.form),
              onStartDifferent: _startDifferent,
            )
          else if (flex == null)
            accountsState.isLoading ||
                    accounts == null && !accountsState.isError
                ? const ApiLoadingSection(label: 'Loading your account')
                : const ApiStateCard(
                    title: 'No Flex account',
                    message: 'You need an active Flex account to send money.',
                    tone: ApiStateTone.info,
                  )
          else
            ...switch (_step) {
              _Step.form => _form(flex.availableBalance, {
                for (final a in accounts!.accounts) a.accountNumber,
              }),
              _Step.review => _review(),
            },
        ],
      ),
    );
  }

  List<Widget> _form(String? available, Set<String> ownNumbers) {
    final number = _account.text.trim();
    final numberError = number.isEmpty
        ? null
        : !_tenDigits.hasMatch(number)
        ? 'Enter a 10-digit account number.'
        : ownNumbers.contains(number)
        ? 'Use "Between my accounts" for your own accounts.'
        : null;
    final amount = amountWithin(_amount.text, available);
    final ready =
        number.isNotEmpty &&
        numberError == null &&
        amount is ValidMoney &&
        narrationFits(_narration.text);
    return [
      const FlowHeading('Who are you sending to?'),
      AppTextField(
        label: 'BOCTRUST account number',
        controller: _account,
        hintText: '10 digits',
        keyboardType: TextInputType.number,
        onChanged: (_) => _edit(),
      ),
      if (numberError != null) FieldError(numberError),
      const SizedBox(height: BocSpace.sm),
      CoreAmountFields(
        input: amount,
        available: available,
        amount: _amount,
        narration: _narration,
        onChanged: _edit,
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Review',
        onPressed: ready
            ? () => setState(() {
                _draft = BoctrustTransferDraft(
                  toAccountNumber: number,
                  amountKobo: amount.minorUnits,
                  narration: _narration.text,
                );
                _step = _Step.review;
              })
            : null,
      ),
    ];
  }

  List<Widget> _review() {
    final draft = _draft;
    if (draft == null) return const [];
    final amount = nairaFromKobo(draft.amountKobo);
    final narration = draft.narration?.trim() ?? '';
    return [
      CoreReviewCard(
        caption: "You're sending",
        amount: amount,
        rows: [
          (label: 'Bank', value: 'BOCTRUST'),
          (label: 'Account number', value: maskNumber(draft.toAccountNumber)),
          if (narration.isNotEmpty) (label: 'Narration', value: narration),
        ],
      ),
      const SizedBox(height: BocSpace.md),
      const ApiStateCard(
        title: 'Check the account number',
        message:
            'We cannot show the account name for this transfer. Money sent '
            'to the wrong account cannot be reversed.',
        tone: ApiStateTone.warning,
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Send $amount',
        onPressed: () => _confirm(draft, amount),
      ),
    ];
  }

  Future<void> _confirm(BoctrustTransferDraft draft, String amount) =>
      authorizeAndSubmitTransfer(
        context,
        ref,
        draft: draft,
        summary: TransactionSummary(
          title: 'Send to BOCTRUST account',
          amountDisplay: amount,
          lines: [('To', maskNumber(draft.toAccountNumber))],
        ),
      );
}
