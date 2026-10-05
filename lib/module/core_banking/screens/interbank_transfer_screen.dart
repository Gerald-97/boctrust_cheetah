import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/core_money.dart';
import '../model/core_submission_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../service/core_transfer_service.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';

enum _Step { recipient, amount, review, result }

final _tenDigits = RegExp(r'^\d{10}$');

/// Sends money from BocFlex to an account at another bank.
///
/// The receiving account must be confirmed by name enquiry first; changing
/// the bank or any digit discards that confirmation.
class InterbankTransferFlow extends ConsumerStatefulWidget {
  const InterbankTransferFlow({
    required this.onExit,
    required this.onSectionSelected,
    super.key,
  });

  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<InterbankTransferFlow> createState() =>
      _InterbankTransferFlowState();
}

class _InterbankTransferFlowState extends ConsumerState<InterbankTransferFlow> {
  final _account = TextEditingController();
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  _Step _step = _Step.recipient;
  CommercialBank? _bank;
  ResolvedRecipient? _recipient;
  bool _resolving = false;
  String? _resolveError;
  int _lookup = 0;
  InterbankTransferDraft? _draft;
  InterbankTransferStatus? _status;
  bool _checkingStatus = false;
  String? _statusError;

  bool get _beneficiaries => ref
      .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
      .isAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(interbankTransferProvider.notifier).clear();
      for (final load in [
        if (ref.read(interbankBanksProvider).data == null)
          ref.read(interbankBanksProvider.notifier).load,
        if (ref.read(customerBankAccountsProvider).data == null)
          ref.read(customerBankAccountsProvider.notifier).load,
        if (ref
                .read(
                  featureAvailabilityProvider(FeatureCapability.beneficiaries),
                )
                .isAvailable &&
            ref.read(beneficiariesProvider).data == null)
          ref.read(beneficiariesProvider.notifier).load,
      ]) {
        unawaited(load());
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

  /// Any recipient change discards the confirmed name and a late lookup.
  void _changeRecipient(VoidCallback change) => setState(() {
    change();
    _lookup++;
    _recipient = null;
    _resolving = false;
    _resolveError = null;
    _draft = null;
  });

  Future<void> _resolve() async {
    final bank = _bank;
    final number = _account.text.trim();
    if (bank == null || !_tenDigits.hasMatch(number) || _resolving) return;
    final lookup = ++_lookup;
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    final result = await ref
        .read(coreTransferServiceProvider)
        .nameEnquiry(bankCode: bank.code, accountNumber: number);
    if (!mounted || lookup != _lookup) return;
    final name = result.data?.name;
    setState(() {
      _resolving = false;
      _recipient = name == null
          ? null
          : ResolvedRecipient(
              bankCode: bank.code,
              bankName: bank.name,
              accountNumber: number,
              name: name,
            );
      _resolveError = name == null
          ? "We couldn't find this account. Check the bank and number."
          : null;
    });
  }

  void _useBeneficiary(Beneficiary saved, List<CommercialBank> banks) {
    final code = saved.bankCode;
    if (code == null) return;
    _account.text = saved.number;
    _changeRecipient(
      () => _bank =
          banks.where((bank) => bank.code == code).firstOrNull ??
          CommercialBank(code: code, name: saved.bankName ?? code),
    );
    unawaited(_resolve());
  }

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(interbankTransferProvider);
    return AppScaffold(
      title: 'To another bank',
      activeSection: AppSection.send,
      onBack: switch (_step) {
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
        children: switch (_step) {
          _Step.recipient => _recipientStep(),
          _Step.amount => _amountStep(),
          _Step.review => _review(),
          _Step.result => [
            CoreSubmissionResult(
              inFlight: submission.inFlight,
              outcome: submission.outcome,
              noun: 'Transfer',
              onDone: widget.onExit,
              onChangeDetails: () {
                ref.read(interbankTransferProvider.notifier).reset();
                setState(() => _step = _Step.recipient);
              },
              acceptedExtra: switch (submission.outcome) {
                AcceptedSubmission(:final ack) => _afterAccepted(ack),
                _ => const [],
              },
            ),
          ],
        },
      ),
    );
  }

  List<Widget> _recipientStep() {
    final banksState = ref.watch(interbankBanksProvider);
    final banks = banksState.data ?? const <CommercialBank>[];
    final saved = _beneficiaries
        ? [
            for (final b
                in ref.watch(beneficiariesProvider).data ??
                    const <Beneficiary>[])
              if (b.type == BeneficiaryType.bankAccount) b,
          ]
        : const <Beneficiary>[];
    final number = _account.text.trim();
    final recipient = _recipient;
    return [
      const FlowHeading('Who are you sending to?'),
      if (saved.isNotEmpty) ...[
        SettingsGroup(
          caption: 'Saved beneficiaries',
          padding: const EdgeInsets.only(bottom: BocSpace.md),
          children: [
            for (final b in saved)
              ListTile(
                title: Text(b.nickname ?? b.name),
                subtitle: Text(
                  '${b.bankName ?? b.bankCode ?? ''} · ${b.maskedNumber}',
                ),
                onTap: () => _useBeneficiary(b, banks),
              ),
          ],
        ),
      ],
      if (banksState.isError && banks.isEmpty)
        ApiStateCard(
          title: 'Banks unavailable',
          message: banksState.message ?? 'We could not load banks.',
          tone: ApiStateTone.error,
          actionLabel: 'Retry',
          onAction: ref.read(interbankBanksProvider.notifier).load,
        )
      else
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_bank?.name ?? 'Choose a bank'),
          subtitle: banksState.isLoading && banks.isEmpty
              ? const Text('Loading banks…')
              : null,
          trailing: const Icon(IconsaxPlusLinear.arrow_down_1),
          onTap: banks.isEmpty
              ? null
              : () async {
                  final bank = await showBankPicker(context, banks);
                  if (bank != null) _changeRecipient(() => _bank = bank);
                },
        ),
      const SizedBox(height: BocSpace.sm),
      AppTextField(
        label: 'Account number',
        controller: _account,
        hintText: '10 digits',
        keyboardType: TextInputType.number,
        onChanged: (_) => _changeRecipient(() {}),
      ),
      const SizedBox(height: BocSpace.sm),
      if (recipient != null)
        ApiStateCard(
          title: recipient.name,
          message: '${recipient.bankName} · ${recipient.accountNumber}',
          tone: ApiStateTone.info,
        )
      else if (_resolveError != null)
        FieldError(_resolveError!),
      const SizedBox(height: BocSpace.lg),
      if (recipient == null)
        PrimaryButton(
          label: 'Check account',
          isLoading: _resolving,
          onPressed: _bank != null && _tenDigits.hasMatch(number)
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

  List<Widget> _amountStep() {
    final recipient = _recipient;
    if (recipient == null) return const [];
    final available = ref
        .watch(customerBankAccountsProvider)
        .data
        ?.activeFlexAccount
        ?.availableBalance;
    final amount = parseNairaToKobo(
      _amount.text,
      maxKobo: balanceToKobo(available) ?? '0',
    );
    final message = amountError(_amount.text, amount);
    final narrationTooLong =
        _narration.text.trim().length > kNarrationMaxLength;
    return [
      FlowHeading('How much to ${recipient.name}?'),
      AppTextField(
        label: 'Amount (₦)',
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() => _draft = null),
      ),
      if (message != null) FieldError(message),
      const SizedBox(height: BocSpace.xxs),
      Text(
        'Available: ${formatApiAmount(available, currency: 'NGN') ?? 'unavailable'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: BocSpace.sm),
      AppTextField(
        label: 'Narration (optional)',
        controller: _narration,
        onChanged: (_) => setState(() => _draft = null),
        validator: (_) => narrationTooLong
            ? 'Use $kNarrationMaxLength characters or fewer.'
            : null,
        autovalidateMode: AutovalidateMode.always,
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Review',
        onPressed: amount is ValidMoney && !narrationTooLong
            ? () => setState(() {
                _draft = InterbankTransferDraft(
                  bankCode: recipient.bankCode,
                  bankName: recipient.bankName,
                  accountNumber: recipient.accountNumber,
                  accountName: recipient.name,
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
          (label: 'To', value: draft.accountName),
          (label: 'Bank', value: draft.bankName),
          (label: 'Account', value: draft.accountNumber),
          (label: 'Amount', value: amount),
          if (narration.isNotEmpty) (label: 'Narration', value: narration),
        ],
      ),
      const SizedBox(height: BocSpace.sm),
      Text(
        'Any fee is applied by the bank when the transfer is processed.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Send $amount',
        onPressed: () => _confirm(draft, amount),
      ),
    ];
  }

  Future<void> _confirm(InterbankTransferDraft draft, String amount) async {
    final authorized = await authorizeCoreTransaction(
      context,
      ref,
      TransactionSummary(
        title: 'Send to ${draft.accountName}',
        amountDisplay: amount,
        lines: [('Bank', draft.bankName), ('Account', draft.accountNumber)],
      ),
    );
    if (!authorized || !mounted) return;
    setState(() {
      _step = _Step.result;
      _status = null;
      _statusError = null;
    });
    await ref.read(interbankTransferProvider.notifier).submit(draft);
    if (!mounted) return;
    unawaited(ref.read(customerBankAccountsProvider.notifier).load());
  }

  Future<void> _checkStatus(String reference) async {
    setState(() {
      _checkingStatus = true;
      _statusError = null;
    });
    final result = await ref
        .read(coreTransferServiceProvider)
        .getTransferStatus(reference);
    if (!mounted) return;
    setState(() {
      _checkingStatus = false;
      _status = result.data ?? _status;
      _statusError = result.data == null
          ? result.message ?? 'We could not check this transfer.'
          : null;
    });
    if (result.data?.state == InterbankTransferState.completed) {
      unawaited(ref.read(customerBankAccountsProvider.notifier).load());
    }
  }

  List<Widget> _afterAccepted(CoreTransferAck ack) {
    final reference = ack.reference;
    final draft = _draft;
    final status = _status;
    final alreadySaved =
        draft == null ||
        (ref.watch(beneficiariesProvider).data ?? const <Beneficiary>[]).any(
          (b) =>
              b.bankCode == draft.bankCode && b.number == draft.accountNumber,
        );
    return [
      const SizedBox(height: BocSpace.md),
      if (reference == null)
        const ApiStateCard(
          title: 'Status unavailable',
          message:
              'No reference was returned, so this transfer cannot be '
              'tracked here. Check your balance shortly.',
          tone: ApiStateTone.info,
        )
      else ...[
        if (status != null)
          ApiStateCard(
            title: switch (status.state) {
              InterbankTransferState.completed => 'Transfer completed',
              InterbankTransferState.failed => 'Transfer failed',
              InterbankTransferState.pending => 'Transfer processing',
              InterbankTransferState.unknown => 'Status not recognised',
            },
            message: status.message ?? 'Reference $reference',
            tone: switch (status.state) {
              InterbankTransferState.completed => ApiStateTone.info,
              InterbankTransferState.failed => ApiStateTone.error,
              _ => ApiStateTone.warning,
            },
          ),
        if (_statusError != null) FieldError(_statusError!),
        if (status == null ||
            status.state == InterbankTransferState.pending ||
            status.state == InterbankTransferState.unknown) ...[
          const SizedBox(height: BocSpace.sm),
          SecondaryButton(
            label: _checkingStatus ? 'Checking…' : 'Check status',
            onPressed: _checkingStatus ? null : () => _checkStatus(reference),
          ),
        ],
      ],
      if (_beneficiaries && !alreadySaved) ...[
        const SizedBox(height: BocSpace.sm),
        SecondaryButton(
          label: 'Save as beneficiary',
          onPressed: () async {
            final error = await ref
                .read(beneficiariesProvider.notifier)
                .add(
                  bankBeneficiaryRequest(
                    bankCode: draft.bankCode,
                    number: draft.accountNumber,
                  ),
                );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error ?? 'Beneficiary saved.')),
            );
          },
        ),
      ],
    ];
  }
}
