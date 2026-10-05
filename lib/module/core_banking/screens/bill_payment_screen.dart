import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/beneficiary_models.dart';
import '../model/bill_models.dart';
import '../model/core_money.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../service/transaction_authorizer.dart';
import 'core_flow_widgets.dart';

enum BillPaymentKind {
  airtime('Airtime'),
  data('Data'),
  bills('Pay bills');

  const BillPaymentKind(this.title);
  final String title;

  bool includes(BillerCategory category) => switch (this) {
    airtime => category.isAirtime,
    data => category.isData && !category.isAirtime,
    bills => !category.isAirtime && !category.isData,
  };
}

enum _Step { category, biller, item, details, review, result }

/// Pays airtime, data or a bill from BocFlex: category, biller, plan, the
/// customer's identifier with the biller, then the amount.
class BillPaymentFlow extends ConsumerStatefulWidget {
  const BillPaymentFlow({
    required this.kind,
    required this.onExit,
    required this.onSectionSelected,
    super.key,
  });

  final BillPaymentKind kind;
  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<BillPaymentFlow> createState() => _BillPaymentFlowState();
}

class _BillPaymentFlowState extends ConsumerState<BillPaymentFlow> {
  final _customerId = TextEditingController();
  final _amount = TextEditingController();
  _Step _step = _Step.category;
  BillerCategory? _category;
  Biller? _biller;
  PaymentItem? _item;
  BillPaymentDraft? _draft;

  bool get _beneficiaries => ref
      .watch(featureAvailabilityProvider(FeatureCapability.beneficiaries))
      .isAvailable;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(billPaymentProvider.notifier).clear();
      final beneficiaries = ref
          .read(featureAvailabilityProvider(FeatureCapability.beneficiaries))
          .isAvailable;
      for (final (data, load) in [
        (
          ref.read(billerCategoriesProvider).data,
          ref.read(billerCategoriesProvider.notifier).load,
        ),
        (
          ref.read(billersProvider).data,
          ref.read(billersProvider.notifier).load,
        ),
        (
          ref.read(paymentItemsProvider).data,
          ref.read(paymentItemsProvider.notifier).load,
        ),
        (
          ref.read(customerBankAccountsProvider).data,
          ref.read(customerBankAccountsProvider.notifier).load,
        ),
        if (beneficiaries)
          (
            ref.read(beneficiariesProvider).data,
            ref.read(beneficiariesProvider.notifier).load,
          ),
      ]) {
        if (data == null) unawaited(load());
      }
    });
  }

  @override
  void dispose() {
    _customerId.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _go(_Step step, [VoidCallback? change]) => setState(() {
    change?.call();
    _draft = null;
    _step = step;
  });

  VoidCallback get _back => switch (_step) {
    _Step.category || _Step.result => widget.onExit,
    _Step.biller => () => _go(_Step.category),
    _Step.item => () => _go(_Step.biller),
    _Step.details => () => _go(_Step.item),
    _Step.review => () => _go(_Step.details),
  };

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(billPaymentProvider);
    return AppScaffold(
      title: widget.kind.title,
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: widget.onSectionSelected,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: switch (_step) {
          _Step.category => _categories(),
          _Step.biller => _billers(),
          _Step.item => _items(),
          _Step.details => _details(),
          _Step.review => _review(),
          _Step.result => [
            CoreSubmissionResult(
              inFlight: submission.inFlight,
              outcome: submission.outcome,
              noun: 'Payment',
              onDone: widget.onExit,
              onChangeDetails: () {
                ref.read(billPaymentProvider.notifier).reset();
                _go(_Step.details);
              },
              acceptedExtra: _saveBeneficiary(),
            ),
          ],
        },
      ),
    );
  }

  /// A loading, error or empty card for a catalogue read, or null when its
  /// rows are ready.
  Widget? _catalogueState<T>(
    NotifierState<List<T>> state,
    Future<Object?> Function() retry,
    String empty,
  ) {
    final rows = state.data;
    if (rows == null) {
      return state.isError
          ? ApiStateCard(
              title: 'Unavailable',
              message: state.message ?? 'We could not load this list.',
              tone: ApiStateTone.error,
              actionLabel: 'Retry',
              onAction: retry,
            )
          : const ApiLoadingSection(label: 'Loading');
    }
    return rows.isEmpty
        ? ApiStateCard(
            title: 'Nothing here',
            message: empty,
            tone: ApiStateTone.info,
          )
        : null;
  }

  Widget _choice(String title, VoidCallback onTap, {String? subtitle}) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: const Icon(IconsaxPlusLinear.arrow_right_3),
        onTap: onTap,
      );

  List<Widget> _categories() {
    final state = ref.watch(billerCategoriesProvider);
    final notice = _catalogueState(
      state,
      ref.read(billerCategoriesProvider.notifier).load,
      'No bill categories are available.',
    );
    if (notice != null) return [notice];
    final all = state.data!;
    final matching = all.where(widget.kind.includes).toList();
    // No published flag for this kind: offer everything rather than nothing.
    final shown = matching.isEmpty ? all : matching;
    return [
      const FlowHeading('Choose a category'),
      for (final category in shown)
        _choice(
          category.name,
          () => _go(_Step.biller, () => _category = category),
          subtitle: category.description,
        ),
    ];
  }

  List<Widget> _billers() {
    final category = _category;
    final state = ref.watch(billersProvider);
    final notice = _catalogueState(
      state,
      ref.read(billersProvider.notifier).load,
      'No billers are available.',
    );
    if (notice != null || category == null) return [?notice];
    final billers = [
      for (final biller in state.data!)
        if (biller.categoryId == category.id) biller,
    ];
    return [
      FlowHeading(category.name),
      if (billers.isEmpty)
        const ApiStateCard(
          title: 'No billers',
          message: 'No billers are available in this category.',
          tone: ApiStateTone.info,
        ),
      for (final biller in billers)
        _choice(biller.name, () => _go(_Step.item, () => _biller = biller)),
    ];
  }

  List<Widget> _items() {
    final biller = _biller;
    final state = ref.watch(paymentItemsProvider);
    final notice = _catalogueState(
      state,
      ref.read(paymentItemsProvider.notifier).load,
      'No plans are available.',
    );
    if (notice != null || biller == null) return [?notice];
    final items = [
      for (final item in state.data!)
        if (item.billerId == biller.id) item,
    ];
    return [
      FlowHeading(biller.name),
      if (items.isEmpty)
        const ApiStateCard(
          title: 'No plans',
          message: 'This biller has no plans available.',
          tone: ApiStateTone.info,
        ),
      for (final item in items)
        _choice(
          item.name,
          () => _go(_Step.details, () {
            _item = item;
            _amount.clear();
          }),
          subtitle: item.amountNaira == null
              ? 'Enter amount'
              : formatApiAmount(item.amountNaira, currency: 'NGN'),
        ),
    ];
  }

  List<Widget> _details() {
    final biller = _biller;
    final item = _item;
    if (biller == null || item == null) return const [];
    final available = ref
        .watch(customerBankAccountsProvider)
        .data
        ?.activeFlexAccount
        ?.availableBalance;
    final fixed = item.amountNaira;
    final amountText = fixed ?? _amount.text;
    final amount = parseNairaAmount(
      amountText,
      maxKobo: balanceToKobo(available) ?? '0',
    );
    final message = amountError(amountText, amount);
    final customerId = _customerId.text.trim();
    final saved = _beneficiaries
        ? [
            for (final b
                in ref.watch(beneficiariesProvider).data ??
                    const <Beneficiary>[])
              if (b.billerId == biller.id) b,
          ]
        : const <Beneficiary>[];
    return [
      FlowHeading(item.name),
      for (final b in saved)
        _choice(b.nickname ?? b.maskedNumber, () {
          _customerId.text = b.number;
          _go(_Step.details);
        }, subtitle: b.paymentItemName),
      AppTextField(
        label: biller.customerFieldLabel,
        controller: _customerId,
        keyboardType: widget.kind == BillPaymentKind.bills
            ? TextInputType.text
            : TextInputType.phone,
        onChanged: (_) => _go(_Step.details),
      ),
      const SizedBox(height: BocSpace.sm),
      if (fixed == null)
        AppTextField(
          label: 'Amount (₦)',
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _go(_Step.details),
        )
      else
        BocSummaryGrid(
          items: [
            (
              label: 'Amount',
              value: formatApiAmount(fixed, currency: 'NGN') ?? fixed,
            ),
          ],
        ),
      if (message != null) FieldError(message),
      const SizedBox(height: BocSpace.xxs),
      Text(
        'Available: ${formatApiAmount(available, currency: 'NGN') ?? 'unavailable'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Review',
        onPressed: customerId.isNotEmpty && amount is ValidMoney
            ? () => _go(
                _Step.review,
                () => _draft = BillPaymentDraft(
                  billerId: biller.id,
                  paymentItemId: item.id,
                  customerId: customerId,
                  amountNaira: amount.minorUnits,
                ),
              )
            : null,
      ),
    ];
  }

  List<Widget> _review() {
    final draft = _draft;
    final biller = _biller;
    final item = _item;
    if (draft == null || biller == null || item == null) return const [];
    final amount =
        formatApiAmount(draft.amountNaira, currency: 'NGN') ??
        draft.amountNaira;
    return [
      const FlowHeading('Review your payment'),
      BocSummaryGrid(
        items: [
          (label: 'Biller', value: biller.name),
          (label: 'Plan', value: item.name),
          (label: biller.customerFieldLabel, value: draft.customerId),
          (label: 'Amount', value: amount),
        ],
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(
        label: 'Pay $amount',
        onPressed: () => _confirm(draft, biller, amount),
      ),
    ];
  }

  Future<void> _confirm(
    BillPaymentDraft draft,
    Biller biller,
    String amount,
  ) async {
    final authorized = await authorizeCoreTransaction(
      context,
      ref,
      TransactionSummary(
        title: 'Pay ${biller.name}',
        amountDisplay: amount,
        lines: [(biller.customerFieldLabel, draft.customerId)],
      ),
    );
    if (!authorized || !mounted) return;
    setState(() => _step = _Step.result);
    await ref.read(billPaymentProvider.notifier).submit(draft);
    if (!mounted) return;
    unawaited(ref.read(customerBankAccountsProvider.notifier).load());
  }

  List<Widget> _saveBeneficiary() {
    final draft = _draft;
    final category = _category;
    final biller = _biller;
    final item = _item;
    final type = category == null
        ? null
        : BeneficiaryType.forCategoryName(category.name);
    if (!_beneficiaries ||
        draft == null ||
        category == null ||
        biller == null ||
        item == null ||
        type == null) {
      return const [];
    }
    final saved = (ref.watch(beneficiariesProvider).data ?? const []).any(
      (b) => b.billerId == biller.id && b.number == draft.customerId,
    );
    if (saved) return const [];
    return [
      const SizedBox(height: BocSpace.sm),
      SecondaryButton(
        label: 'Save as beneficiary',
        onPressed: () async {
          final error = await ref
              .read(beneficiariesProvider.notifier)
              .add(
                billBeneficiaryRequest(
                  type: type,
                  billerId: biller.id,
                  billerName: biller.name,
                  categoryId: category.id,
                  categoryName: category.name,
                  paymentItemId: item.id,
                  paymentItemName: item.name,
                  number: draft.customerId,
                ),
              );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'Beneficiary saved.')),
          );
        },
      ),
    ];
  }
}
