import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../model/core_money.dart';
import '../model/customer_bank_account_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/intrabank_submission_providers.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';

enum _MoveStep { form, review, result }

/// Moves money between BocFlex and one of the customer's savings product
/// accounts. Only the directions whose capability is available are offered,
/// and nothing is sent until the transaction is authorized.
class OwnAccountMoveFlow extends ConsumerStatefulWidget {
  const OwnAccountMoveFlow({
    required this.onExit,
    required this.onSectionSelected,
    super.key,
  });

  final VoidCallback onExit;

  /// A bottom-navigation tab, which leaves the flow for that section.
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<OwnAccountMoveFlow> createState() => _OwnAccountMoveFlowState();
}

class _OwnAccountMoveFlowState extends ConsumerState<OwnAccountMoveFlow> {
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  _MoveStep _step = _MoveStep.form;
  OwnAccountDirection? _direction;
  String? _productCode;
  OwnAccountMoveDraft? _draft;

  @override
  void initState() {
    super.initState();
    for (final controller in [_amount, _narration]) {
      controller.addListener(() => setState(() {}));
    }
    // A previous visit's result must never show on a new move.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ownAccountMoveProvider.notifier).clear();
      unawaited(ref.read(customerBankAccountsProvider.notifier).ensureLoaded());
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _narration.dispose();
    super.dispose();
  }

  List<OwnAccountDirection> get _directions => [
    if (_available(FeatureCapability.ownAccountTransfers))
      OwnAccountDirection.toSavings,
    if (_available(FeatureCapability.savingsWithdrawals))
      OwnAccountDirection.toFlex,
  ];

  bool _available(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  /// Editing anything after review discards the reviewed draft.
  void _edit(VoidCallback change) => setState(() {
    change();
    _draft = null;
    _step = _MoveStep.form;
  });

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(customerBankAccountsProvider);
    final accounts = accountsState.data;
    final flex = accounts?.activeFlexAccount;
    final products = [
      for (final account in accounts?.accounts ?? const <CustomerBankAccount>[])
        if (account.isActive && account.productCode != kFlexProductCode)
          account,
    ];
    final directions = _directions;
    final direction = directions.contains(_direction)
        ? _direction!
        : directions.firstOrNull;
    final product = products
        .where((account) => account.productCode == _productCode)
        .firstOrNull;

    return AppScaffold(
      title: 'Between my accounts',
      activeSection: AppSection.send,
      onBack: switch (_step) {
        _MoveStep.review => () => setState(() => _step = _MoveStep.form),
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
          if (accounts == null && accountsState.isError)
            ApiStateCard(
              title: 'Accounts unavailable',
              message:
                  accountsState.message ?? 'We could not load your accounts.',
              tone: ApiStateTone.error,
              actionLabel: 'Retry',
              onAction: ref.read(customerBankAccountsProvider.notifier).load,
            )
          else if (accounts == null)
            const ApiLoadingSection(label: 'Loading your accounts')
          else if (flex == null || products.isEmpty || direction == null)
            const ApiStateCard(
              title: 'Nothing to move between yet',
              message:
                  'You need an active Flex account and a savings account to '
                  'move money between them.',
              tone: ApiStateTone.info,
            )
          else
            ...switch (_step) {
              _MoveStep.form => _form(directions, direction, flex, products),
              _MoveStep.review => _review(flex, product),
              _MoveStep.result => _result(),
            },
        ],
      ),
    );
  }

  List<Widget> _form(
    List<OwnAccountDirection> directions,
    OwnAccountDirection direction,
    CustomerBankAccount flex,
    List<CustomerBankAccount> products,
  ) {
    final product = products
        .where((account) => account.productCode == _productCode)
        .firstOrNull;
    final source = direction == OwnAccountDirection.toSavings ? flex : product;
    // Moving to Flex draws on the chosen savings account, so there is no
    // balance to check until one is picked.
    final amount = source == null
        ? const InvalidMoney('Choose the account to move from first.')
        : amountWithin(_amount.text, source.availableBalance);
    final ready =
        product != null &&
        amount is ValidMoney &&
        narrationFits(_narration.text);

    return [
      if (directions.length > 1) ...[
        SegmentedButton<OwnAccountDirection>(
          segments: const [
            ButtonSegment(
              value: OwnAccountDirection.toSavings,
              label: Text('To savings'),
            ),
            ButtonSegment(
              value: OwnAccountDirection.toFlex,
              label: Text('To Flex'),
            ),
          ],
          selected: {direction},
          onSelectionChanged: (value) => _edit(() => _direction = value.single),
        ),
        const SizedBox(height: BocSpace.md),
      ],
      FormDropdown<String>(
        label: direction == OwnAccountDirection.toSavings
            ? 'Move to'
            : 'Move from',
        value: product?.productCode,
        items: [
          for (final account in products)
            DropdownMenuItem(
              value: account.productCode,
              child: Text(account.productName),
            ),
        ],
        onChanged: (code) => _edit(() => _productCode = code),
      ),
      const SizedBox(height: BocSpace.sm),
      CoreAmountFields(
        input: amount,
        available: source?.availableBalance,
        amount: _amount,
        narration: _narration,
        onChanged: () => _edit(() {}),
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Review',
        onPressed: ready
            ? () => setState(() {
                _draft = OwnAccountMoveDraft(
                  direction: direction,
                  productCode: product.productCode,
                  amountKobo: amount.minorUnits,
                  narration: _narration.text,
                );
                _step = _MoveStep.review;
              })
            : null,
      ),
    ];
  }

  List<Widget> _review(CustomerBankAccount flex, CustomerBankAccount? product) {
    final draft = _draft;
    if (draft == null || product == null) return const [];
    final toSavings = draft.direction == OwnAccountDirection.toSavings;
    final amount = nairaFromKobo(draft.amountKobo);
    final narration = draft.narration?.trim() ?? '';
    return [
      CoreReviewCard(
        caption: "You're moving",
        amount: amount,
        rows: [
          (
            label: 'From',
            value: toSavings ? flex.productName : product.productName,
          ),
          (
            label: 'To',
            value: toSavings ? product.productName : flex.productName,
          ),
          if (narration.isNotEmpty) (label: 'Narration', value: narration),
        ],
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Confirm',
        onPressed: () => _confirm(
          draft,
          TransactionSummary(
            title: toSavings ? 'Move to savings' : 'Move to Flex',
            amountDisplay: amount,
          ),
        ),
      ),
    ];
  }

  Future<void> _confirm(
    OwnAccountMoveDraft draft,
    TransactionSummary summary,
  ) async {
    final authorized = await authorizeCoreTransaction(context, ref, summary);
    if (!authorized || !mounted) return;
    setState(() => _step = _MoveStep.result);
    await ref.read(ownAccountMoveProvider.notifier).submit(draft);
    if (!mounted) return;
    // Balances come from Core only; never subtract locally.
    unawaited(ref.read(customerBankAccountsProvider.notifier).load());
  }

  List<Widget> _result() {
    final state = ref.watch(ownAccountMoveProvider);
    return [
      CoreSubmissionResult(
        inFlight: state.inFlight,
        outcome: state.outcome,
        noun: 'Transfer',
        amount: _draft == null ? null : nairaFromKobo(_draft!.amountKobo),
        details: [
          if (_draft case final draft?)
            (
              label: draft.direction == OwnAccountDirection.toSavings
                  ? 'To'
                  : 'From',
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
        onDone: widget.onExit,
        onChangeDetails: () {
          ref.read(ownAccountMoveProvider.notifier).reset();
          setState(() => _step = _MoveStep.form);
        },
      ),
    ];
  }
}
