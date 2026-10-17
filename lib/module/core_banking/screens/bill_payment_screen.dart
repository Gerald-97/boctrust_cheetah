import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../../app/session_scoped_notifier.dart';
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
import 'transaction_pin_sheet.dart';

enum _Step { category, biller, item, details, review, result }

/// Pays airtime, data or a bill from BocFlex: biller, plan, the customer's
/// identifier with the biller, then the amount. A tile's [group] opens its
/// billers directly; [BillerGroup.all] starts from the full category list,
/// whose search also finds billers in every category.
class BillPaymentFlow extends ConsumerStatefulWidget {
  const BillPaymentFlow({
    required this.group,
    required this.onExit,
    required this.onSectionSelected,
    this.searchFirst = false,
    super.key,
  });

  final BillerGroup group;

  /// Focuses the first step's search field on open.
  final bool searchFirst;
  final VoidCallback onExit;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  ConsumerState<BillPaymentFlow> createState() => _BillPaymentFlowState();
}

class _BillPaymentFlowState extends ConsumerState<BillPaymentFlow> {
  final _customerId = TextEditingController();
  final _amount = TextEditingController();
  late _Step _step = widget.group == BillerGroup.all
      ? _Step.category
      : _Step.biller;
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
      for (final notifier in <SessionScopedNotifier<Object?>>[
        ref.read(billerCategoriesProvider.notifier),
        ref.read(billersProvider.notifier),
        ref.read(paymentItemsProvider.notifier),
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
    _customerId.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// Moves to [step]. The reviewed draft is dropped first, so a [change]
  /// that builds a new draft keeps it.
  void _go(_Step step, [VoidCallback? change]) => setState(() {
    if (step != _step) _query = '';
    _draft = null;
    change?.call();
    _step = step;
  });

  VoidCallback get _back => switch (_step) {
    _Step.category || _Step.result => widget.onExit,
    _Step.biller =>
      widget.group == BillerGroup.all
          ? () => _go(_Step.category)
          : widget.onExit,
    _Step.item => () => _go(_Step.biller),
    _Step.details => () => _go(_Step.item),
    _Step.review => () => _go(_Step.details),
  };

  @override
  Widget build(BuildContext context) {
    final submission = ref.watch(billPaymentProvider);
    return AppScaffold(
      title: widget.group.title,
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
              codeConfirmsCompletion: true,
              amount: _draft == null
                  ? null
                  : formatApiAmount(_draft!.amountNaira, currency: 'NGN'),
              details: [
                if ((_biller, _item, _draft) case (
                  final biller?,
                  final item?,
                  final draft?,
                )) ...[
                  (label: 'Biller', value: biller.name),
                  (label: 'Plan', value: item.name),
                  (label: biller.customerFieldLabel, value: draft.customerId),
                ],
              ],
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

  String _query = '';

  bool _matchesQuery(String text) =>
      _query.isEmpty || text.toLowerCase().contains(_query);

  Widget _search(String hint, {bool autofocus = false}) => CoreSearchField(
    key: ValueKey(_step),
    hintText: hint,
    autofocus: autofocus,
    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
  );

  /// Tappable rows in one grouped card, as on the Account settings.
  Widget _group(List<Widget> tiles) =>
      SettingsGroup(padding: EdgeInsets.zero, children: tiles);

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => SettingsTile(icon: icon, title: title, subtitle: subtitle, onTap: onTap);

  static IconData _iconOf(BillerGroup? group) => switch (group) {
    BillerGroup.airtime => IconsaxPlusLinear.mobile,
    BillerGroup.data => IconsaxPlusLinear.chart,
    BillerGroup.electricity => IconsaxPlusLinear.flash,
    BillerGroup.water => IconsaxPlusLinear.drop,
    BillerGroup.cableTv => IconsaxPlusLinear.monitor,
    BillerGroup.internet => IconsaxPlusLinear.wifi,
    BillerGroup.education => IconsaxPlusLinear.teacher,
    BillerGroup.all || null => IconsaxPlusLinear.receipt_item,
  };

  /// The tile this biller belongs to: the one opened, or (from More) the
  /// one its name and category suggest.
  BillerGroup? _groupOf(Biller biller) =>
      widget.group == BillerGroup.all ? BillerGroup.of(biller) : widget.group;

  /// Billers sorted by name, recomputed only when the list itself changes.
  List<Biller>? _billerSource;
  List<Biller> _sortedBillers = const [];
  List<Biller> _sorted(List<Biller> source) {
    if (!identical(source, _billerSource)) {
      _billerSource = source;
      _sortedBillers = [...source]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return _sortedBillers;
  }

  List<Widget> _categories() {
    final state = ref.watch(billerCategoriesProvider);
    final notice = _catalogueState(
      state,
      ref.read(billerCategoriesProvider.notifier).load,
      'No bill categories are available.',
    );
    if (notice != null) return [notice];
    final categories = [
      for (final category in state.data!)
        if (_matchesQuery(category.name)) category,
    ];
    final categoryById = {for (final c in state.data!) c.id: c};
    final billers = _query.isEmpty
        ? const <Biller>[]
        : [
            for (final biller in _sorted(
              ref.watch(billersProvider).data ?? const [],
            ))
              if (categoryById.containsKey(biller.categoryId) &&
                  _matchesQuery(biller.name))
                biller,
          ];
    return [
      const FlowHeading('What would you like to pay?'),
      _search('Search categories or billers', autofocus: widget.searchFirst),
      if (categories.isEmpty && billers.isEmpty)
        const ApiStateCard(
          title: 'No matches',
          message: 'No category or biller matches your search.',
          tone: ApiStateTone.info,
        ),
      if (categories.isNotEmpty)
        _group([
          for (final category in categories)
            _tile(
              _iconOf(BillerGroup.ofCategory(category.name)),
              category.name,
              category.description ?? 'See billers',
              () => _go(_Step.biller, () => _category = category),
            ),
        ]),
      if (billers.isNotEmpty) ...[
        if (categories.isNotEmpty) const SizedBox(height: BocSpace.md),
        _group([
          for (final biller in billers)
            _tile(
              _iconOf(_groupOf(biller)),
              biller.name,
              biller.customerFieldLabel,
              () => _go(_Step.item, () {
                _category = categoryById[biller.categoryId];
                _biller = biller;
              }),
            ),
        ]),
      ],
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
    final byCategory = widget.group == BillerGroup.all;
    if (notice != null) return [notice];
    if (byCategory && category == null) return const [];
    final billers = [
      for (final biller in _sorted(state.data!))
        if ((byCategory
                ? biller.categoryId == category!.id
                : widget.group.matches(biller)) &&
            _matchesQuery(biller.name))
          biller,
    ];
    return [
      FlowHeading(byCategory ? category!.name : 'Choose a provider'),
      _search('Search billers'),
      if (billers.isEmpty)
        ApiStateCard(
          title: _query.isEmpty ? 'No billers' : 'No matches',
          message: _query.isEmpty
              ? 'No billers are available here yet.'
              : 'No biller matches your search.',
          tone: ApiStateTone.info,
        )
      else
        _group([
          for (final biller in billers)
            _tile(
              _iconOf(_groupOf(biller)),
              biller.name,
              biller.customerFieldLabel,
              () => _go(_Step.item, () => _biller = biller),
            ),
        ]),
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
    final shown = [
      for (final item in items)
        if (_matchesQuery(item.name)) item,
    ];
    return [
      FlowHeading(biller.name),
      if (items.length > 6) _search('Search plans'),
      if (items.isEmpty)
        const ApiStateCard(
          title: 'No plans',
          message: 'This biller has no plans available.',
          tone: ApiStateTone.info,
        )
      else if (shown.isEmpty)
        const ApiStateCard(
          title: 'No matches',
          message: 'No plan matches your search.',
          tone: ApiStateTone.info,
        )
      else
        _group([
          for (final item in shown)
            _tile(
              IconsaxPlusLinear.receipt_item,
              item.name,
              item.amountNaira == null
                  ? 'Enter your amount'
                  : formatApiAmount(item.amountNaira, currency: 'NGN') ?? '',
              () => _go(_Step.details, () {
                _item = item;
                _amount.clear();
              }),
            ),
        ]),
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
    final amount = amountWithin(fixed ?? _amount.text, available, naira: true);
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
      if (saved.isNotEmpty) ...[
        SettingsGroup(
          caption: 'Saved',
          padding: const EdgeInsets.only(bottom: BocSpace.md),
          children: [
            for (final b in saved)
              _tile(
                IconsaxPlusLinear.profile,
                b.nickname ?? b.maskedNumber,
                b.paymentItemName ?? b.maskedNumber,
                () {
                  _customerId.text = b.number;
                  _go(_Step.details);
                },
              ),
          ],
        ),
      ],
      AppTextField(
        label: biller.customerFieldLabel,
        controller: _customerId,
        keyboardType:
            widget.group == BillerGroup.airtime ||
                widget.group == BillerGroup.data
            ? TextInputType.phone
            : TextInputType.text,
        onChanged: (_) => _go(_Step.details),
      ),
      const SizedBox(height: BocSpace.sm),
      CoreAmountFields(
        input: amount,
        available: available,
        amount: fixed == null ? _amount : null,
        fixedAmount: fixed,
        onChanged: () => _go(_Step.details),
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
      CoreReviewCard(
        caption: "You're paying",
        amount: amount,
        rows: [
          (label: 'Biller', value: biller.name),
          (label: 'Plan', value: item.name),
          (label: biller.customerFieldLabel, value: draft.customerId),
        ],
      ),
      const SizedBox(height: BocSpace.lg),
      PrimaryButton(label: 'Pay $amount', onPressed: () => _confirm(draft)),
    ];
  }

  Future<void> _confirm(BillPaymentDraft draft) async {
    final biller = _biller;
    final item = _item;
    if (biller == null || item == null) return;
    final pin = await collectCoreTransactionPin(
      context,
      TransactionSummary(
        title: 'Pay ${biller.name}',
        amountDisplay:
            formatApiAmount(draft.amountNaira, currency: 'NGN') ??
            draft.amountNaira,
        lines: [
          ('Plan', item.name),
          (biller.customerFieldLabel, draft.customerId),
        ],
      ),
      confirmLabel: 'Confirm payment',
    );
    if (pin == null || !mounted) return;
    setState(() => _step = _Step.result);
    await ref
        .read(billPaymentProvider.notifier)
        .submit(draft, transactionPin: pin);
  }

  List<Widget> _saveBeneficiary() {
    final draft = _draft;
    final biller = _biller;
    final item = _item;
    final type = biller == null ? null : _groupOf(biller)?.beneficiaryType;
    if (!_beneficiaries ||
        draft == null ||
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
      SaveBeneficiaryButton(
        body: billBeneficiaryRequest(
          type: type,
          billerId: biller.id,
          billerName: biller.name,
          categoryId: biller.categoryId,
          categoryName: biller.categoryName ?? _category?.name ?? '',
          paymentItemId: item.id,
          paymentItemName: item.name,
          number: draft.customerId,
        ),
      ),
    ];
  }
}
