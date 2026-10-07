import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_money.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/core_transfer_service.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'snap_number_button.dart';
import 'core_transfer_attempt_view.dart';

enum _Step { recipient, amount, review }

final _tenDigits = RegExp(r'^\d{10}$');

/// Sends money from BocFlex to another BOCTRUST customer.
///
/// The receiving BOCTRUST account must be confirmed by name enquiry first;
/// changing any digit discards that confirmation.
class BoctrustTransferFlow extends ConsumerStatefulWidget {
  const BoctrustTransferFlow({
    required this.onExit,
    required this.onSectionSelected,
    this.initialAccountNumber,
    super.key,
  });

  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  /// Prefills the account number, e.g. one read from a photo.
  final String? initialAccountNumber;

  @override
  ConsumerState<BoctrustTransferFlow> createState() =>
      _BoctrustTransferFlowState();
}

class _BoctrustTransferFlowState extends ConsumerState<BoctrustTransferFlow> {
  late final _account = TextEditingController(
    text: widget.initialAccountNumber,
  );

  bool get _canSnap => ref
      .watch(featureAvailabilityProvider(FeatureCapability.scanToPay))
      .isAvailable;
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  _Step _step = _Step.recipient;
  String? _recipientName;
  bool _resolving = false;
  String? _resolveError;
  int _lookup = 0;
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

  void _changeRecipient(VoidCallback change) => setState(() {
    change();
    _lookup++;
    _recipientName = null;
    _resolving = false;
    _resolveError = null;
    _draft = null;
    _step = _Step.recipient;
  });

  Future<void> _resolve() async {
    final number = _account.text.trim();
    if (!_tenDigits.hasMatch(number) || _resolving) return;
    final lookup = ++_lookup;
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    final result = accountNameLookupOutcome(
      await ref.read(coreTransferServiceProvider).boctrustNameEnquiry(number),
    );
    if (!mounted || lookup != _lookup) return;
    setState(() {
      _resolving = false;
      _recipientName = result.name;
      _resolveError = result.error;
    });
  }

  /// An empty form, after an unresolved transfer is set aside.
  void _startDifferent() => setState(() {
    for (final controller in [_account, _amount, _narration]) {
      controller.clear();
    }
    _lookup++;
    _recipientName = null;
    _resolving = false;
    _resolveError = null;
    _draft = null;
    _step = _Step.recipient;
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
      onBack: showsAttempt(attempt)
          ? widget.onExit
          : switch (_step) {
              _Step.amount => () => setState(() => _step = _Step.recipient),
              _Step.review => () => setState(() => _step = _Step.amount),
              _ => widget.onExit,
            },
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
              onEditDetails: () => setState(() => _step = _Step.recipient),
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
              _Step.recipient => _recipientStep({
                for (final a in accounts!.accounts) a.accountNumber,
              }),
              _Step.amount => _amountStep(flex.availableBalance),
              _Step.review => _review(),
            },
        ],
      ),
    );
  }

  List<Widget> _recipientStep(Set<String> ownNumbers) {
    final number = _account.text.trim();
    final numberError = number.isEmpty
        ? null
        : !_tenDigits.hasMatch(number)
        ? 'Enter a 10-digit account number.'
        : ownNumbers.contains(number)
        ? 'Use "Between my accounts" for your own accounts.'
        : null;
    final name = _recipientName;
    return [
      const FlowHeading('Who are you sending to?'),
      AppTextField(
        label: 'BOCTRUST account number',
        controller: _account,
        hintText: '10 digits',
        keyboardType: TextInputType.number,
        onChanged: (_) => _changeRecipient(() {}),
        suffix: _canSnap
            ? SnapNumberButton(
                onNumber: (number) {
                  _account.text = number;
                  _changeRecipient(() {});
                },
              )
            : null,
      ),
      if (numberError != null) FieldError(numberError),
      const SizedBox(height: BocSpace.md),
      if (name != null)
        ApiStateCard(
          title: name,
          message: 'BOCTRUST · $number',
          tone: ApiStateTone.info,
        )
      else if (_resolveError != null)
        FieldError(_resolveError!),
      const SizedBox(height: BocSpace.lg),
      if (name == null)
        PrimaryButton(
          label: 'Check account',
          isLoading: _resolving,
          onPressed: numberError == null && _tenDigits.hasMatch(number)
              ? _resolve
              : null,
        )
      else
        PrimaryButton(
          label: 'Continue',
          onPressed: () => setState(() => _step = _Step.amount),
        ),
    ];
  }

  List<Widget> _amountStep(String? available) {
    final name = _recipientName;
    if (name == null) return const [];
    final amount = amountWithin(_amount.text, available);
    return [
      FlowHeading('How much to $name?'),
      CoreAmountFields(
        input: amount,
        available: available,
        amount: _amount,
        narration: _narration,
        onChanged: () => setState(() => _draft = null),
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Review',
        onPressed: amount is ValidMoney && narrationFits(_narration.text)
            ? () => setState(() {
                _draft = BoctrustTransferDraft(
                  toAccountNumber: _account.text.trim(),
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
    final name = _recipientName;
    if (draft == null || name == null) return const [];
    final amount = nairaFromKobo(draft.amountKobo);
    final narration = draft.narration?.trim() ?? '';
    return [
      CoreReviewCard(
        caption: "You're sending",
        amount: amount,
        rows: [
          (label: 'Bank', value: 'BOCTRUST'),
          (label: 'Account name', value: name),
          (label: 'Account number', value: maskNumber(draft.toAccountNumber)),
          if (narration.isNotEmpty) (label: 'Narration', value: narration),
        ],
      ),
      const SizedBox(height: BocSpace.md),
      PrimaryButton(
        label: 'Send $amount',
        onPressed: () => _confirm(draft, amount, name),
      ),
    ];
  }

  Future<void> _confirm(
    BoctrustTransferDraft draft,
    String amount,
    String name,
  ) => authorizeAndSubmitTransfer(
    context,
    ref,
    draft: draft,
    summary: TransactionSummary(
      title: 'Send to BOCTRUST account',
      amountDisplay: amount,
      lines: [('To', name), ('Account', maskNumber(draft.toAccountNumber))],
    ),
  );
}
