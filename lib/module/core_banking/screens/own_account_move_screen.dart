import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_flow_navigator.dart';
import '../../component/text_fields.dart';
import '../model/core_money.dart';
import '../model/core_submission_models.dart';
import '../model/customer_bank_account_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/intrabank_submission_providers.dart';
import '../service/transaction_authorizer.dart';

enum _MoveStep { form, review, result }

/// Moves money between BocFlex and one of the customer's savings product
/// accounts. Only the directions whose capability is available are offered,
/// and nothing is sent until the transaction is authorized.
class OwnAccountMoveFlow extends ConsumerStatefulWidget {
  const OwnAccountMoveFlow({required this.onExit, super.key});

  final VoidCallback onExit;

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
      if (mounted) ref.read(ownAccountMoveProvider.notifier).clear();
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
    final accounts = ref.watch(customerBankAccountsProvider).data;
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
      onSectionSelected: (_) => widget.onExit(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          if (flex == null || products.isEmpty || direction == null)
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
    final amount = parseNairaToKobo(
      _amount.text,
      maxKobo: balanceToKobo(source?.availableBalance) ?? '0',
    );
    final narrationTooLong =
        _narration.text.trim().length > kNarrationMaxLength;
    final amountError = _amount.text.trim().isEmpty
        ? null
        : switch (amount) {
            InvalidMoney(:final message) => message,
            ValidMoney() => null,
          };
    final ready = product != null && amount is ValidMoney && !narrationTooLong;

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
      AppTextField(
        label: 'Amount (₦)',
        controller: _amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _edit(() {}),
      ),
      if (amountError != null) ...[
        const SizedBox(height: BocSpace.xxs),
        Text(
          amountError,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ],
      if (source != null) ...[
        const SizedBox(height: BocSpace.xxs),
        Text(
          'Available: ${formatApiAmount(source.availableBalance, currency: 'NGN') ?? 'unavailable'}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
      const SizedBox(height: BocSpace.sm),
      AppTextField(
        label: 'Narration (optional)',
        controller: _narration,
        onChanged: (_) => _edit(() {}),
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

  String _naira(String kobo) =>
      formatApiAmount(
        '${kobo.substring(0, kobo.length - 2).padLeft(1, '0')}.'
        '${kobo.substring(kobo.length - 2)}',
        currency: 'NGN',
      ) ??
      '';

  List<Widget> _review(CustomerBankAccount flex, CustomerBankAccount? product) {
    final draft = _draft;
    if (draft == null || product == null) return const [];
    final toSavings = draft.direction == OwnAccountDirection.toSavings;
    final amount = _naira(draft.amountKobo.padLeft(3, '0'));
    final narration = draft.narration?.trim() ?? '';
    return [
      BocSummaryGrid(
        items: [
          (
            label: 'From',
            value: toSavings ? flex.productName : product.productName,
          ),
          (
            label: 'To',
            value: toSavings ? product.productName : flex.productName,
          ),
          (label: 'Amount', value: amount),
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
    final authorized = await ref
        .read(transactionAuthorizerProvider)
        .authorize(context, summary);
    if (!mounted) return;
    if (!authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This transfer was not authorized.')),
      );
      return;
    }
    setState(() => _step = _MoveStep.result);
    await ref.read(ownAccountMoveProvider.notifier).submit(draft);
    if (!mounted) return;
    // Balances come from Core only; never subtract locally.
    unawaited(ref.read(customerBankAccountsProvider.notifier).load());
  }

  List<Widget> _result() {
    final state = ref.watch(ownAccountMoveProvider);
    if (state.inFlight) {
      return const [ApiLoadingSection(label: 'Sending your transfer')];
    }
    return switch (state.outcome) {
      AcceptedSubmission(:final ack) => [
        ApiStateCard(
          title: 'Transfer submitted',
          message: ack.reference == null
              ? 'Your balances will update shortly.'
              : 'Reference ${ack.reference}. Your balances will update '
                    'shortly.',
          tone: ApiStateTone.info,
        ),
        const SizedBox(height: BocSpace.md),
        PrimaryButton(label: 'Done', onPressed: widget.onExit),
      ],
      RejectedSubmission(:final message) => [
        ApiStateCard(
          title: 'Transfer declined',
          message: message,
          tone: ApiStateTone.error,
        ),
        const SizedBox(height: BocSpace.md),
        PrimaryButton(
          label: 'Change details',
          onPressed: () {
            ref.read(ownAccountMoveProvider.notifier).reset();
            setState(() => _step = _MoveStep.form);
          },
        ),
      ],
      // Unknown: never resend, never claim an outcome.
      final UnknownSubmission unknown => [
        ApiStateCard(
          title: 'Transfer not confirmed',
          message: unknown.message,
          tone: ApiStateTone.warning,
        ),
        const SizedBox(height: BocSpace.md),
        PrimaryButton(label: 'Done', onPressed: widget.onExit),
      ],
      null => const [],
    };
  }
}
