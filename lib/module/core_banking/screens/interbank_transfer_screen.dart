import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/input_formatters.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/core_money.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../provider/core_transfer_attempt_provider.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';
import 'snap_number_button.dart';
import 'core_transfer_attempt_view.dart';

enum _Step { recipient, amount, review }

final _tenDigits = RegExp(r'^\d{10}$');

/// Sends money from BocFlex to an account at another bank or, with
/// [InterbankTransferFlow.boctrust], to another BOCTRUST customer.
///
/// The receiving account must be confirmed by name enquiry first; changing
/// the bank or any digit discards that confirmation. BOCTRUST uses the same
/// screen and name enquiry with Boctrust MFB preselected, but the money moves
/// through the intrabank routes.
class InterbankTransferFlow extends ConsumerStatefulWidget {
  const InterbankTransferFlow({
    required this.onExit,
    required this.onSectionSelected,
    this.initialAccountNumber,
    this.initialBankCode,
    super.key,
  }) : boctrust = false;

  const InterbankTransferFlow.boctrust({
    required this.onExit,
    required this.onSectionSelected,
    this.initialAccountNumber,
    super.key,
  }) : boctrust = true,
       initialBankCode = null;

  /// Boctrust MFB is fixed as the bank and the transfer is intrabank.
  final bool boctrust;

  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  /// Prefills the account number, e.g. one read from a photo.
  final String? initialAccountNumber;
  final String? initialBankCode;

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
  CancelToken? _lookupToken;

  /// A [BoctrustTransferDraft] or an [InterbankTransferDraft], as reviewed.
  Object? _draft;

  bool get _beneficiaries => ref
      .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
      .isAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final banksLoad = ref
          .read(interbankBanksProvider.notifier)
          .ensureLoaded();
      unawaited(ref.read(customerBankAccountsProvider.notifier).ensureLoaded());
      if (ref
          .read(featureAvailabilityProvider(FeatureCapability.beneficiaries))
          .isAvailable) {
        unawaited(ref.read(beneficiariesProvider.notifier).ensureLoaded());
      }
      await banksLoad;
      if (!mounted) return;
      if (widget.boctrust) {
        final boctrust = CommercialBank.boctrustIn(
          ref.read(interbankBanksProvider).data ?? const [],
        );
        if (boctrust != null) _changeRecipient(() => _bank = boctrust);
        return;
      }
      final initialBankCode = widget.initialBankCode;
      if (initialBankCode != null && _bank == null) {
        final initialBank = ref
            .read(interbankBanksProvider)
            .data
            ?.where((bank) => bank.code == initialBankCode && !bank.isBoctrust)
            .firstOrNull;
        if (initialBank != null) _changeRecipient(() => _bank = initialBank);
      }
    });
  }

  @override
  void dispose() {
    _lookupToken?.cancel();
    for (final controller in [_account, _amount, _narration]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Any recipient change cancels a lookup in flight, discards the
  /// confirmed name, and looks the account up again once the bank is chosen
  /// and the number is complete.
  void _changeRecipient(VoidCallback change) {
    _lookupToken?.cancel();
    _lookupToken = null;
    setState(() {
      change();
      _lookup++;
      _recipient = null;
      _resolving = false;
      _resolveError = null;
      _draft = null;
    });
    unawaited(_resolve());
  }

  Future<void> _resolve() async {
    final bank = _bank;
    final number = _account.text.trim();
    if (bank == null || !_tenDigits.hasMatch(number) || _resolving) return;
    if (widget.boctrust && _ownNumbers.contains(number)) return;
    final lookup = ++_lookup;
    final token = _lookupToken = CancelToken();
    setState(() {
      _resolving = true;
      _resolveError = null;
    });
    final result = await lookUpAccountName(
      ref,
      bankCode: bank.code,
      accountNumber: number,
      cancelToken: token,
    );
    if (!mounted || lookup != _lookup) return;
    _lookupToken = null;
    setState(() {
      _resolving = false;
      _recipient = result.name == null
          ? null
          : ResolvedRecipient(
              bankCode: bank.code,
              bankName: bank.name,
              accountNumber: number,
              name: result.name!,
            );
      _resolveError = result.error;
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
  }

  Set<String> get _ownNumbers => {
    for (final account
        in ref.read(customerBankAccountsProvider).data?.accounts ?? const [])
      account.accountNumber,
  };

  /// An empty form, after an unresolved transfer is set aside.
  void _startDifferent() {
    for (final controller in [_account, _amount, _narration]) {
      controller.clear();
    }
    _changeRecipient(() {
      if (!widget.boctrust) _bank = null;
      _step = _Step.recipient;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(coreTransferAttemptProvider).current;
    return AppScaffold(
      title: widget.boctrust ? 'To a BOCTRUST account' : 'To another bank',
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
    final allBanks = banksState.data ?? const <CommercialBank>[];
    // BOCTRUST recipients are paid through the intrabank flow, never here:
    // neither its bank nor a beneficiary saved at it is offered.
    final banks = [
      for (final bank in allBanks)
        if (!bank.isBoctrust) bank,
    ];
    final boctrustCode = CommercialBank.boctrustIn(allBanks)?.code;
    final saved = _beneficiaries && !widget.boctrust
        ? [
            for (final b
                in ref.watch(beneficiariesProvider).data ??
                    const <Beneficiary>[])
              if (b.type == BeneficiaryType.bankAccount &&
                  b.bankCode != boctrustCode &&
                  !CommercialBank(
                    code: b.bankCode ?? '',
                    name: b.bankName ?? '',
                  ).isBoctrust)
                b,
          ]
        : const <Beneficiary>[];
    final number = _account.text.trim();
    final recipient = _recipient;
    final ownNumber =
        widget.boctrust &&
        (ref.watch(customerBankAccountsProvider).data?.accounts ?? const [])
            .any((account) => account.accountNumber == number);
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
      if (widget.boctrust)
        if (_bank == null && (banksState.isDone || banksState.isError))
          const ApiStateCard(
            title: 'BOCTRUST transfers unavailable',
            message:
                "We couldn't find BOCTRUST in the bank list. Try again "
                'later.',
            tone: ApiStateTone.error,
          )
        else
          const SizedBox.shrink()
      else if (banksState.isError && banks.isEmpty)
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
        inputFormatters: bankAccountNumberInputFormatters(),
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
      if (ownNumber) const FieldError('Choose a different recipient account.'),
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
          onPressed: _bank != null && _tenDigits.hasMatch(number) && !ownNumber
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
                _draft = widget.boctrust
                    ? BoctrustTransferDraft(
                        toAccountNumber: recipient.accountNumber,
                        amountKobo: amount.minorUnits,
                        narration: _narration.text,
                      )
                    : InterbankTransferDraft(
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
    final recipient = _recipient;
    if (draft == null || recipient == null) return const [];
    final (amountKobo, narration) = switch (draft) {
      BoctrustTransferDraft(:final amountKobo, :final narration) => (
        amountKobo,
        narration,
      ),
      InterbankTransferDraft(:final amountKobo, :final narration) => (
        amountKobo,
        narration,
      ),
      _ => throw ArgumentError.value(draft, 'draft'),
    };
    final amount = nairaFromKobo(amountKobo);
    final note = narration?.trim() ?? '';
    return [
      CoreReviewCard(
        caption: "You're sending",
        amount: amount,
        rows: [
          (label: 'To', value: recipient.name),
          (label: 'Bank', value: recipient.bankName),
          (label: 'Account number', value: recipient.accountNumber),
          if (note.isNotEmpty) (label: 'Narration', value: note),
        ],
      ),
      if (!widget.boctrust) ...[
        const SizedBox(height: BocSpace.sm),
        Text(
          'Any fee is applied by the bank when the transfer is processed.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Send $amount',
        onPressed: () => authorizeStagedTransfer(
          context,
          ref,
          draft: draft,
          summary: TransactionSummary(
            title: 'Send to ${recipient.name}',
            amountDisplay: amount,
            lines: [
              ('Bank', recipient.bankName),
              ('Account', recipient.accountNumber),
            ],
          ),
        ),
      ),
    ];
  }
}
