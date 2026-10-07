import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/session_scoped_notifier.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/core_money.dart';
import '../model/interbank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'snap_number_button.dart';
import 'core_transfer_attempt_view.dart';

enum _Step { recipient, amount, review }

final _tenDigits = RegExp(r'^\d{10}$');

/// Sends money from BocFlex to an account at another bank.
///
/// The receiving account must be confirmed by name enquiry first; changing
/// the bank or any digit discards that confirmation.
class InterbankTransferFlow extends ConsumerStatefulWidget {
  const InterbankTransferFlow({
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
  ConsumerState<InterbankTransferFlow> createState() =>
      _InterbankTransferFlowState();
}

class _InterbankTransferFlowState extends ConsumerState<InterbankTransferFlow> {
  late final _account = TextEditingController(
    text: widget.initialAccountNumber,
  );

  bool get _canSnap => ref
      .watch(featureAvailabilityProvider(FeatureCapability.scanToPay))
      .isAvailable;
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  _Step _step = _Step.recipient;
  CommercialBank? _bank;
  ResolvedRecipient? _recipient;
  bool _resolving = false;
  String? _resolveError;
  int _lookup = 0;
  InterbankTransferDraft? _draft;

  bool get _beneficiaries => ref
      .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
      .isAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final notifier in <SessionScopedNotifier<Object?>>[
        ref.read(interbankBanksProvider.notifier),
        ref.read(customerBankAccountsProvider.notifier),
        if (ref
            .read(featureAvailabilityProvider(FeatureCapability.beneficiaries))
            .isAvailable)
          ref.read(beneficiariesProvider.notifier),
      ]) {
        unawaited(notifier.ensureLoaded());
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
    final name = await lookUpAccountName(
      ref,
      bankCode: bank.code,
      accountNumber: number,
    );
    if (!mounted || lookup != _lookup) return;
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
      _resolveError = name == null ? kAccountNotFound : null;
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

  /// An empty form, after an unresolved transfer is set aside.
  void _startDifferent() {
    for (final controller in [_account, _amount, _narration]) {
      controller.clear();
    }
    _changeRecipient(() {
      _bank = null;
      _step = _Step.recipient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(coreTransferAttemptProvider).current;
    return AppScaffold(
      title: 'To another bank',
      activeSection: AppSection.send,
      onBack: switch (showsAttempt(attempt) ? null : _step) {
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
        children: showsAttempt(attempt)
            ? [
                CoreTransferAttemptView(
                  attempt: attempt!,
                  onExit: widget.onExit,
                  onEditDetails: () => setState(() => _step = _Step.recipient),
                  onStartDifferent: _startDifferent,
                ),
              ]
            : [
                const SetAsideTransfers(),
                ...switch (_step) {
                  _Step.recipient => _recipientStep(),
                  _Step.amount => _amountStep(),
                  _Step.review => _review(),
                },
              ],
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
              SettingsTile(
                icon: IconsaxPlusLinear.profile,
                title: b.nickname ?? b.name,
                subtitle:
                    '${b.bankName ?? b.bankCode ?? ''} · ${b.maskedNumber}',
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
        BankSelectorTile(
          bank: _bank,
          banks: banks,
          loading: banksState.isLoading,
          onSelected: (bank) => _changeRecipient(() => _bank = bank),
        ),
      const SizedBox(height: BocSpace.md),
      AppTextField(
        label: 'Account number',
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
    final amount = amountWithin(_amount.text, available);
    return [
      FlowHeading('How much to ${recipient.name}?'),
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
      CoreReviewCard(
        caption: "You're sending",
        amount: amount,
        rows: [
          (label: 'To', value: draft.accountName),
          (label: 'Bank', value: draft.bankName),
          (label: 'Account number', value: draft.accountNumber),
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

  Future<void> _confirm(InterbankTransferDraft draft, String amount) =>
      authorizeAndSubmitTransfer(
        context,
        ref,
        draft: draft,
        summary: TransactionSummary(
          title: 'Send to ${draft.accountName}',
          amountDisplay: amount,
          lines: [('Bank', draft.bankName), ('Account', draft.accountNumber)],
        ),
      );
}
