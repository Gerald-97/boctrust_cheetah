import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_money.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';

enum _Step { form, review, result }

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
      ref.read(boctrustTransferProvider.notifier).clear();
      if (ref.read(customerBankAccountsProvider).data == null) {
        unawaited(ref.read(customerBankAccountsProvider.notifier).load());
      }
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

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(customerBankAccountsProvider);
    final accounts = accountsState.data;
    final flex = accounts?.activeFlexAccount;
    return AppScaffold(
      title: 'To a BOCTRUST account',
      activeSection: AppSection.send,
      onBack: _step == _Step.review
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
          if (flex == null)
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
              _Step.result => [
                CoreSubmissionResult(
                  inFlight: ref.watch(boctrustTransferProvider).inFlight,
                  outcome: ref.watch(boctrustTransferProvider).outcome,
                  noun: 'Transfer',
                  onDone: widget.onExit,
                  onChangeDetails: () {
                    ref.read(boctrustTransferProvider.notifier).reset();
                    setState(() => _step = _Step.form);
                  },
                ),
              ],
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
    final amount = parseNairaToKobo(
      _amount.text,
      maxKobo: balanceToKobo(available) ?? '0',
    );
    final amountMessage = amountError(_amount.text, amount);
    final narrationTooLong =
        _narration.text.trim().length > kNarrationMaxLength;
    final ready =
        number.isNotEmpty &&
        numberError == null &&
        amount is ValidMoney &&
        !narrationTooLong;
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
      AppTextField(
        label: 'Amount (₦)',
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _edit(),
      ),
      if (amountMessage != null) FieldError(amountMessage),
      const SizedBox(height: BocSpace.xxs),
      Text(
        'Available: ${formatApiAmount(available, currency: 'NGN') ?? 'unavailable'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: BocSpace.sm),
      AppTextField(
        label: 'Narration (optional)',
        controller: _narration,
        onChanged: (_) => _edit(),
        validator: (_) => narrationTooLong
            ? 'Use $kNarrationMaxLength characters or fewer.'
            : null,
        autovalidateMode: AutovalidateMode.always,
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
      const FlowHeading('Review your transfer'),
      BocSummaryGrid(
        items: [
          (label: 'To account', value: maskNumber(draft.toAccountNumber)),
          (label: 'Amount', value: amount),
          if (narration.isNotEmpty) (label: 'Narration', value: narration),
        ],
      ),
      const SizedBox(height: BocSpace.sm),
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

  Future<void> _confirm(BoctrustTransferDraft draft, String amount) async {
    final authorized = await authorizeCoreTransaction(
      context,
      ref,
      TransactionSummary(
        title: 'Send to BOCTRUST account',
        amountDisplay: amount,
        lines: [('To', maskNumber(draft.toAccountNumber))],
      ),
    );
    if (!authorized || !mounted) return;
    setState(() => _step = _Step.result);
    await ref.read(boctrustTransferProvider.notifier).submit(draft);
    if (!mounted) return;
    unawaited(ref.read(customerBankAccountsProvider.notifier).load());
  }
}
