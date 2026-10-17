part of 'savings_screens.dart';

/// Plan lists, detail and management. Everything shown comes from Core;
/// with no server plan the screen explains the gap. Deposit, edit
/// and withdraw are each gated by their own capability.
extension SavingsPlanScreens on FlowPageState {
  Color _productAccent(SavingsProductType type) {
    final colors = context.bocColors;
    return switch (type) {
      SavingsProductType.flex => colors.flexAccent,
      SavingsProductType.smartSave => colors.smartSaveAccent,
      SavingsProductType.fixed => colors.fixedAccent,
      SavingsProductType.padi => colors.padiAccent,
    };
  }

  Color _productContainer(SavingsProductType type) {
    final colors = context.bocColors;
    return switch (type) {
      SavingsProductType.flex => colors.flexContainer,
      SavingsProductType.smartSave => colors.smartSaveContainer,
      SavingsProductType.fixed => colors.fixedContainer,
      SavingsProductType.padi => colors.padiContainer,
    };
  }

  IconData _eventIcon(SavingsPlanEventType type) => switch (type) {
    SavingsPlanEventType.topUp => IconsaxPlusLinear.add_circle,
    SavingsPlanEventType.interestCredit => IconsaxPlusLinear.percentage_circle,
    SavingsPlanEventType.withdrawal ||
    SavingsPlanEventType.maturityPayout ||
    SavingsPlanEventType.liquidation => IconsaxPlusLinear.export,
    SavingsPlanEventType.created => IconsaxPlusLinear.flag,
    SavingsPlanEventType.unknown => IconsaxPlusLinear.activity,
  };

  Color _eventAccent(SavingsPlanEventType type, SavingsProductType product) {
    final colors = context.bocColors;
    return switch (type) {
      SavingsPlanEventType.topUp ||
      SavingsPlanEventType.interestCredit => colors.successText,
      SavingsPlanEventType.withdrawal ||
      SavingsPlanEventType.maturityPayout ||
      SavingsPlanEventType.liquidation => colors.errorText,
      _ => _productAccent(product),
    };
  }

  Color _eventContainer(SavingsPlanEventType type, SavingsProductType product) {
    final colors = context.bocColors;
    return switch (type) {
      SavingsPlanEventType.topUp ||
      SavingsPlanEventType.interestCredit => colors.successContainer,
      SavingsPlanEventType.withdrawal ||
      SavingsPlanEventType.maturityPayout ||
      SavingsPlanEventType.liquidation => colors.errorContainer,
      _ => _productContainer(product),
    };
  }

  /// Money in or out; the created and unknown rows carry no direction.
  String _eventSign(SavingsPlanEventType type) => switch (type) {
    SavingsPlanEventType.topUp || SavingsPlanEventType.interestCredit => '+',
    SavingsPlanEventType.withdrawal ||
    SavingsPlanEventType.maturityPayout ||
    SavingsPlanEventType.liquidation => '\u2212',
    _ => '',
  };

  String _planMoney(String? naira) => ref.watch(homeBalanceHiddenProvider)
      ? '₦ ••••••'
      : formatApiAmount(naira, currency: 'NGN') ?? 'Unavailable';

  String? _eventAmount(SavingsPlanEvent event, {required bool hidden}) {
    final amount = event.amount;
    if (amount == null || num.tryParse(amount) == 0) return null;
    final value = hidden
        ? '₦ ••••••'
        : formatApiAmount(amount, currency: 'NGN');
    return value == null
        ? null
        : '${hidden ? '' : _eventSign(event.type)}$value';
  }

  Future<void> _showPlanEvent(SavingsPlan plan, SavingsPlanEvent event) async {
    final hidden = ref.read(homeBalanceHiddenProvider);
    final amount = _eventAmount(event, hidden: hidden);
    final occurred = event.createdAt?.toLocal();
    await AppActionSheet.show<void>(
      context: context,
      builder: (_) => AppActionSheet(
        icon: _eventIcon(event.type),
        iconColor: _eventAccent(event.type, plan.type),
        iconBackground: _eventContainer(event.type, plan.type),
        title: event.type.label,
        subtitle: 'Activity in ${plan.name}',
        child: TransactionDetailRows(
          rows: [
            (label: 'Type', value: event.type.label),
            if (amount != null) (label: 'Amount', value: amount),
            if (occurred != null)
              (
                label: 'Date and time',
                value: DateFormat('d MMM yyyy, h:mm a').format(occurred),
              ),
            (label: 'Plan', value: plan.name),
          ],
        ),
      ),
    );
  }

  /// One product's plans, as Core groups them, with the product balance.
  Widget _savingsPlansScreen(SavingsProductType type, String title) {
    final state = ref.watch(savingsPlansProvider(type));
    final theme = Theme.of(context);
    return AppScaffold(
      title: title,
      activeSection: AppSection.save,
      onBack: back,
      onSectionSelected: goSection,
      body: _plansList(
        type,
        state,
        theme,
        const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
      ),
    );
  }

  Widget _plansList(
    SavingsProductType type,
    AsyncValue<NotifierState<List<SavingsProductGroup>>> state,
    ThemeData theme,
    EdgeInsets padding,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(savingsPlansProvider(type).future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: switch (state) {
          AsyncData(:final value)
              when value.data != null || value.status == ServiceStatus.empty =>
            switch (value.data
                ?.where((group) => group.type == type)
                .firstOrNull) {
              final group? => [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: _productContainer(type),
                              borderRadius: BorderRadius.circular(BocRadius.sm),
                            ),
                            child: SizedBox.square(
                              dimension: 40,
                              child: Icon(
                                type == SavingsProductType.fixed
                                    ? IconsaxPlusLinear.lock
                                    : IconsaxPlusLinear.flag,
                                color: _productAccent(type),
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: BocSpace.sm),
                          Expanded(
                            child: Text(
                              group.productName,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (_frozenAccountNumber(group.accountNumber) != null)
                            const FrozenLabel(),
                        ],
                      ),
                      const SizedBox(height: BocSpace.sm),
                      Text(
                        'Available balance',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: BocSpace.xxs),
                      BocMoneyText(
                        _planMoney(
                          _watchCoreAccounts().data?.accounts
                              .where(
                                (account) =>
                                    account.accountNumber ==
                                    group.accountNumber,
                              )
                              .firstOrNull
                              ?.availableBalance,
                        ),
                        semanticsLabel: 'Product balance',
                      ),
                      if (group.rate != null) ...[
                        const SizedBox(height: BocSpace.xs),
                        Text(
                          '${group.rate}% p.a.',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _productAccent(type),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_frozenAccountNumber(group.accountNumber)
                    case final frozen?)
                  FrozenAccountBanner.savings(frozen, group.productName),
                if (_canCreatePlan(type)) ...[
                  const SizedBox(height: BocSpace.sm),
                  PrimaryButton(
                    label: type == SavingsProductType.fixed
                        ? 'Create a new deposit'
                        : 'Create a new goal',
                    icon: IconsaxPlusLinear.add,
                    onPressed: () => _startPlanCreation(type),
                  ),
                ],
                const SizedBox(height: BocSpace.lg),
                if (group.plans.isEmpty)
                  const ApiStateCard(
                    title: 'No plans yet',
                    message: 'Plans you create will appear here.',
                    tone: ApiStateTone.info,
                  )
                else ...[
                  Semantics(
                    header: true,
                    child: Text(
                      type == SavingsProductType.fixed
                          ? 'Your deposits (${group.plans.length})'
                          : 'Your goals (${group.plans.length})',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  for (final plan in group.plans) ...[
                    const SizedBox(height: BocSpace.sm),
                    _planTile(plan),
                  ],
                ],
              ],
              _ => [
                SavingsEmptyState(
                  icon: IconsaxPlusLinear.save_2,
                  title: 'No ${type.displayName} plans yet',
                  message: 'Plans you create will appear here.',
                  actionLabel: _canCreatePlan(type) ? 'Create a plan' : null,
                  onAction: _canCreatePlan(type)
                      ? () => _startPlanCreation(type)
                      : null,
                ),
              ],
            },
          AsyncData(:final value) => [
            ApiStateCard(
              title: 'Plans unavailable',
              message: value.message ?? "We couldn't load your plans.",
              tone: ApiStateTone.error,
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(savingsPlansProvider(type)),
            ),
          ],
          _ => const [ApiLoadingSection(label: 'Loading your plans')],
        },
      ),
    );
  }

  Widget _planTile(SavingsPlan plan) {
    final theme = Theme.of(context);
    final colors = context.bocColors;
    final maturity = plan.maturityDate;
    return SurfaceCard(
      onTap: () => go(
        AppRoutes.savingsPlanDetail,
        arguments: AppRouteArguments(entityId: plan.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(plan.name, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(width: BocSpace.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: BocSpace.xs,
                  vertical: BocSpace.xxs,
                ),
                decoration: BoxDecoration(
                  color: _productContainer(plan.type),
                  borderRadius: BorderRadius.circular(BocRadius.pill),
                ),
                child: Text(
                  plan.status.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _productAccent(plan.type),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.sm),
          Text('Plan balance', style: theme.textTheme.bodySmall),
          const SizedBox(height: BocSpace.xxs),
          Text(
            _planMoney(plan.principal),
            style: theme.textTheme.titleLarge?.figures,
          ),
          if (maturity != null || plan.target != null) ...[
            const SizedBox(height: BocSpace.sm),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: BocSpace.xs),
            Wrap(
              spacing: BocSpace.sm,
              runSpacing: BocSpace.xxs,
              children: [
                if (plan.target case final target?)
                  Text(
                    'Target ${_planMoney(target)}',
                    style: theme.textTheme.bodySmall,
                  ),
                if (maturity != null)
                  Text(
                    'Matures ${DateFormat('d MMM yyyy').format(maturity)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _savingsPlanDetailScreen() {
    final planId = routeArguments.entityId;
    final state = planId == null
        ? null
        : ref.watch(savingsPlanDetailProvider(planId));
    final detail = state?.value?.data;
    if (detail == null) {
      return AppScaffold(
        title: 'Savings plan',
        activeSection: AppSection.save,
        onBack: back,
        onSectionSelected: goSection,
        body: ListView(
          padding: const EdgeInsets.all(BocSpace.gutter).clearOfNav(context),
          children: [
            switch (state) {
              AsyncData(:final value) when value.statusCode == 404 =>
                ApiStateCard(
                  title: 'Plan unavailable',
                  message: 'This plan is no longer available.',
                  tone: ApiStateTone.info,
                  actionLabel: 'Back to plans',
                  onAction: () {
                    ref.invalidate(savingsPlansProvider);
                    back();
                  },
                ),
              AsyncData(:final value) => ApiStateCard(
                title: 'Plan unavailable',
                message: value.message ?? "We couldn't load this plan.",
                tone: ApiStateTone.error,
                actionLabel: 'Retry',
                onAction: () =>
                    ref.invalidate(savingsPlanDetailProvider(planId!)),
              ),
              null => const ApiStateCard(
                title: 'Plan unavailable',
                message: 'This plan is no longer available.',
                tone: ApiStateTone.info,
              ),
              _ => const ApiLoadingSection(label: 'Loading your plan'),
            },
          ],
        ),
      );
    }
    final plan = detail.plan;
    final theme = Theme.of(context);
    final rate = plan.rate;
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final progress =
        plan.type == SavingsProductType.smartSave &&
            !hidden &&
            (plan.status == SavingsPlanStatus.active ||
                plan.status == SavingsPlanStatus.pendingFunding)
        ? savingsPlanProgress(principal: plan.principal, target: plan.target)
        : null;
    String date(DateTime value) => DateFormat('d MMM yyyy').format(value);
    final productGroup = ref
        .watch(savingsPlansProvider(plan.type))
        .value
        ?.data
        ?.where((group) => group.type == plan.type)
        .firstOrNull;
    final accountNumber = detail.accountNumber ?? productGroup?.accountNumber;
    final frozenAccount = _frozenAccountNumber(accountNumber);
    return AppScaffold(
      title: plan.name,
      activeSection: AppSection.save,
      onBack: back,
      onSectionSelected: goSection,
      actions: [
        PopupMenuButton<String>(
          tooltip: 'More options',
          onSelected: (action) => switch (action) {
            'edit' => _gatedPlanAction(FeatureCapability.savingsPlanEdit),
            'interest' => go(
              AppRoutes.interestHistory,
              arguments: AppRouteArguments(entityId: plan.id),
            ),
            _ when frozenAccount != null =>
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(kSavingsAccountFrozenMessage)),
              ),
            _ => _withdrawFromPlan(plan, accountNumber),
          },
          itemBuilder: (_) => [
            if (ref
                .read(
                  featureAvailabilityProvider(
                    FeatureCapability.savingsPlansView,
                  ),
                )
                .isAvailable)
              const PopupMenuItem(
                value: 'interest',
                child: Text('Interest history'),
              ),
            const PopupMenuItem(value: 'edit', child: Text('Edit plan')),
            const PopupMenuItem(value: 'withdraw', child: Text('Withdraw')),
          ],
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.refresh(savingsPlanDetailProvider(plan.id).future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(
                  BocSpace.gutter,
                ).clearOfNav(context),
                children: [
                  if (frozenAccount != null) ...[
                    FrozenAccountBanner.savings(
                      frozenAccount,
                      plan.type.displayName,
                    ),
                    const SizedBox(height: BocSpace.sm),
                  ],
                  SavingsPlanHero(
                    status: plan.status.label,
                    amount: _planMoney(plan.principal),
                    accent: _productAccent(plan.type),
                    container: _productContainer(plan.type),
                    icon: plan.type == SavingsProductType.fixed
                        ? IconsaxPlusLinear.lock
                        : IconsaxPlusLinear.flag,
                    onDeposit: () => _topUpPlan(plan),
                    rate: rate == null ? null : '$rate% per annum',
                    progress: progress,
                    progressLabel: progress == null
                        ? null
                        : progress.reached
                        ? 'Target reached'
                        : '${_planMoney(plan.principal)} of '
                              '${_planMoney(plan.target)} target',
                  ),
                  const SizedBox(height: BocSpace.md),
                  SavingsFactGroup(
                    title: 'Your plan',
                    rows: [
                      if (plan.target case final target?)
                        (label: 'Target', value: _planMoney(target)),
                      if (plan.type == SavingsProductType.smartSave)
                        (
                          label: 'Auto-save',
                          value: switch ((
                            plan.recurringAmount,
                            plan.saveFrequency,
                          )) {
                            (final amount?, final frequency?) =>
                              '${_planMoney(amount)} '
                                  '${frequency.label.toLowerCase()}',
                            _ => 'Manual deposits',
                          },
                        ),
                      if (plan.startDate case final start?)
                        (label: 'Started', value: date(start)),
                      if (plan.maturityDate case final maturity?)
                        (label: 'Matures', value: date(maturity)),
                      if (plan.tenorDays case final days?)
                        (label: 'Tenor', value: '$days days'),
                    ],
                  ),
                  if (plan.accruedInterest != null ||
                      plan.interestEarned != null ||
                      plan.projectedInterest != null) ...[
                    const SizedBox(height: BocSpace.md),
                    SavingsFactGroup(
                      title: 'Interest & returns',
                      rows: [
                        if (plan.accruedInterest case final accrued?)
                          (
                            label: 'Interest so far',
                            value: _planMoney(accrued),
                          ),
                        if (plan.interestEarned case final interest?)
                          (
                            label: 'Interest earned',
                            value: _planMoney(interest),
                          ),
                        if (plan.projectedInterest case final projected?)
                          (
                            label: 'Projected at maturity',
                            value: _planMoney(projected),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: BocSpace.lg),
                  Semantics(
                    header: true,
                    child: Text('Activity', style: theme.textTheme.titleMedium),
                  ),
                  const SizedBox(height: BocSpace.xs),
                  if (detail.events.isEmpty)
                    SurfaceCard(
                      child: Text(
                        'Deposits, interest and withdrawals will appear here.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  else
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (index, event)
                              in detail.events.indexed) ...[
                            if (index > 0)
                              Divider(
                                height: 1,
                                indent: BocSpace.md,
                                endIndent: BocSpace.md,
                                color: context.bocColors.border,
                              ),
                            SavingsActivityRow(
                              icon: _eventIcon(event.type),
                              label: event.type.label,
                              accent: _eventAccent(event.type, plan.type),
                              container: _eventContainer(event.type, plan.type),
                              date: event.createdAt == null
                                  ? null
                                  : DateFormat(
                                      'd MMM yyyy · h:mm a',
                                    ).format(event.createdAt!.toLocal()),
                              amount: _eventAmount(event, hidden: hidden),
                              onTap: () => _showPlanEvent(plan, event),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _gatedPlanAction(FeatureCapability capability) async {
    if (!ref.read(featureAvailabilityProvider(capability)).isAvailable) {
      await BocUnavailableSheet.show(context);
    }
  }

  Future<void> _topUpPlan(SavingsPlan plan) async {
    if (!ref
        .read(featureAvailabilityProvider(FeatureCapability.savingsPlanDeposit))
        .isAvailable) {
      await BocUnavailableSheet.show(context);
      return;
    }
    // The sheet blocks Back itself while sending; a barrier tap or drag
    // would close it mid-request.
    await AppActionSheet.show<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) =>
          SavingsPlanTopUpSheet(planId: plan.id, planName: plan.name),
    );
  }

  /// Early withdrawal costs a fee on the interest, so it needs an explicit,
  /// clearly labelled confirmation; the safe choice is the prominent one.
  Future<void> _withdrawFromPlan(
    SavingsPlan plan,
    String? accountNumber,
  ) async {
    if (!ref
        .read(
          featureAvailabilityProvider(FeatureCapability.savingsPlanWithdraw),
        )
        .isAvailable) {
      await BocUnavailableSheet.show(context);
      return;
    }
    final matured = plan.status == SavingsPlanStatus.matured;
    final percent = plan.earlyWithdrawalFeePercent;
    final fee = percent == null ? 'the' : 'a $percent%';
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Withdraw?',
      message: matured
          ? 'Your money will move to Boc Flex Savings.'
          : 'Withdrawing early returns your principal and the interest earned '
                'so far to Boc Flex Savings, minus '
                '$fee early withdrawal fee on that interest.',
      confirmLabel: matured ? 'Withdraw' : 'Withdraw early',
      cancelLabel: 'Keep saving',
      destructive: !matured,
    );
    if (!confirmed || !mounted) return;
    final withdrawn = await AppActionSheet.show<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => SavingsPlanWithdrawSheet(
        planId: plan.id,
        accountNumber: accountNumber,
      ),
    );
    if (withdrawn == true && mounted) back();
  }
}

/// One wizard for every savings product: each type contributes its steps,
/// all steps edit one [SavingsPlanDraft], and the draft stays on the device
/// until Core creates the plan. Creating is gated by the product's create
/// capability; SmartSave and Fixed Deposit are created in Core and funded
/// from Boc Flex, and Padi has no Core plan yet.
class _SavingsPlanWizard extends ConsumerStatefulWidget {
  const _SavingsPlanWizard({
    required this.type,
    required this.onExit,
    required this.onCreated,
  });

  final SavingsProductType type;
  final VoidCallback onExit;

  /// Called with the new plan's id once Core confirms it.
  final ValueChanged<String> onCreated;

  @override
  ConsumerState<_SavingsPlanWizard> createState() => _SavingsPlanWizardState();
}

enum _WizardStep { goal, amount, schedule, days, padiGroup, start, confirm }

class _SavingsPlanWizardState extends ConsumerState<_SavingsPlanWizard> {
  late SavingsPlanDraft _draft = SavingsPlanDraft(type: widget.type);
  int _index = 0;
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _recurring = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _recurring.dispose();
    super.dispose();
  }

  List<_WizardStep> get _steps => switch (widget.type) {
    SavingsProductType.smartSave => [
      _WizardStep.goal,
      _WizardStep.schedule,
      if (_draft.autoSave) _WizardStep.days,
      _WizardStep.confirm,
    ],
    SavingsProductType.fixed => [
      _WizardStep.schedule,
      if (_draft.autoSave) _WizardStep.days,
      _WizardStep.confirm,
    ],
    SavingsProductType.padi => [
      _WizardStep.padiGroup,
      _WizardStep.days,
      _WizardStep.start,
      _WizardStep.confirm,
    ],
    SavingsProductType.flex => [_WizardStep.confirm],
  };

  _WizardStep get _step => _steps[_index];

  bool get _amountValid => widget.type == SavingsProductType.smartSave
      ? smartSaveTargetValid(_draft.amount)
      : savingsPlanNaira(_draft.amount) != null;

  /// Created in Core and funded from Boc Flex.
  bool get _createsInCore => widget.type.coreCode != null;

  String get _openingAmount =>
      formatApiAmount('${widget.type.openingMinimumNaira}', currency: 'NGN')!;

  String get _planKind =>
      widget.type == SavingsProductType.fixed ? 'deposit' : 'goal';

  bool get _stepValid => switch (_step) {
    _WizardStep.goal => _draft.name.trim().isNotEmpty && _amountValid,
    _WizardStep.amount => _amountValid,
    _WizardStep.schedule => _draft.tenorDaysOn(DateTime.now()) != null,
    _WizardStep.days when _createsInCore =>
      _draft.frequency != null &&
          savingsPlanNaira(_draft.recurringAmount) != null,
    _WizardStep.days =>
      _draft.frequency != null &&
          (_draft.frequency == SavingsFrequency.daily ||
              _draft.contributionDays.isNotEmpty),
    _WizardStep.padiGroup =>
      _draft.name.trim().isNotEmpty &&
          (_draft.memberCount ?? 0) >= 2 &&
          _amountValid,
    _WizardStep.start => _draft.startDate != null,
    _WizardStep.confirm => true,
  };

  void _update(SavingsPlanDraft next) => setState(() => _draft = next);

  Future<void> _pickMaturityDate() async {
    final today = DateTime.now();
    final minimum = minimumSavingsTenorDays(widget.type);
    final firstDate = DateTime(today.year, today.month, today.day + minimum);
    final lastDate = DateTime(
      today.year,
      today.month,
      today.day + maximumSavingsTenorDays,
    );
    final selected = _draft.customMaturityDate;
    final picked = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate:
          selected != null &&
              !selected.isBefore(firstDate) &&
              !selected.isAfter(lastDate)
          ? selected
          : firstDate,
    );
    if (picked != null && mounted) {
      _update(
        _draft.copyWith(customMaturityDate: picked, clearDurationMonths: true),
      );
    }
  }

  /// Shown on the confirm step when another savings action is sending.
  String? _busy;

  Future<bool> _confirmOpeningTransfer() async {
    final name = _draft.name.trim();
    return await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: const Text('Confirm opening transfer'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name.isNotEmpty) ...[
                  Text(name, style: Theme.of(dialog).textTheme.titleMedium),
                  const SizedBox(height: BocSpace.sm),
                ],
                Text(
                  'Creating this $_planKind moves $_openingAmount from '
                  'Boc Flex Savings into the new plan. This is its minimum '
                  'opening balance.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialog).pop(true),
                child: const Text('Confirm and create'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showCreateFailure(String? message) async {
    final insufficient = RegExp(
      r'insufficient|not enough|low balance',
      caseSensitive: false,
    ).hasMatch(message ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(
          insufficient
              ? 'Not enough in Boc Flex'
              : 'Could not create $_planKind',
        ),
        content: Text(
          insufficient
              ? 'You need at least $_openingAmount in Boc Flex Savings to '
                    'open this $_planKind. Add money to Boc Flex and try again.'
              : message ?? 'Please try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void back() {
    // A create in flight finishes on this screen.
    final action = ref.read(savingsPlanActionProvider);
    if (action.phase == SavingsPlanActionPhase.sending &&
        action.startedBy(SavingsPlanAction.create)) {
      return;
    }
    if (_index == 0) {
      widget.onExit();
    } else {
      setState(() => _index--);
    }
  }

  Future<void> _next() async {
    if (_step != _WizardStep.confirm) {
      setState(() => _index++);
      return;
    }
    if (_draft.tenorDaysOn(DateTime.now()) == null && _createsInCore) {
      setState(() => _index = _steps.indexOf(_WizardStep.schedule));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Choose a date between '
            '${minimumSavingsTenorDays(widget.type)} days and 1 year from today.',
          ),
        ),
      );
      return;
    }
    final capability = widget.type.createCapability;
    final request = _draft.toCreateRequest();
    if (capability == null ||
        !ref.read(featureAvailabilityProvider(capability)).isAvailable ||
        request == null) {
      await BocUnavailableSheet.show(
        context,
        title: '${widget.type.displayName} is not available yet',
      );
      return;
    }
    if (ref.read(savingsPlanActionProvider).busyFor(SavingsPlanAction.create)) {
      setState(() => _busy = savingsPlanBusyMessage);
      return;
    }
    if (_createsInCore && !await _confirmOpeningTransfer()) return;
    if (!mounted) return;
    if (ref.read(savingsPlanActionProvider).busyFor(SavingsPlanAction.create)) {
      setState(() => _busy = savingsPlanBusyMessage);
      return;
    }
    setState(() => _busy = null);
    final actions = ref.read(savingsPlanActionProvider.notifier);
    await actions.create(request);
    if (!mounted) return;
    final action = ref
        .read(savingsPlanActionProvider)
        .viewFor(SavingsPlanAction.create);
    switch (action.phase) {
      case SavingsPlanActionPhase.done:
        final planId = action.planId;
        if (planId != null) widget.onCreated(planId);
      case SavingsPlanActionPhase.unknown:
        // Core may have created it; leave so the customer checks their plans
        // instead of creating it twice.
        await AppActionSheet.show<void>(
          context: context,
          builder: (sheet) => SavingsPlanNotConfirmedSheet(
            message: action.message ?? '',
            onClose: () => Navigator.of(sheet).pop(),
          ),
        );
        if (mounted) widget.onExit();
      case SavingsPlanActionPhase.failed:
        await _showCreateFailure(action.message);
      case SavingsPlanActionPhase.idle || SavingsPlanActionPhase.sending:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _steps;
    final action = ref
        .watch(savingsPlanActionProvider)
        .viewFor(SavingsPlanAction.create);
    final sending = action.phase == SavingsPlanActionPhase.sending;
    final failure = _step == _WizardStep.confirm ? _busy : null;
    final title = switch (widget.type) {
      SavingsProductType.padi => 'Create a Padi',
      SavingsProductType.fixed => 'New Fixed Deposit',
      _ => 'Start a new goal',
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: BocSpace.xs),
            child: BocBackButton(onPressed: back),
          ),
          leadingWidth: BocSpace.minTouch + BocSpace.md,
          title: Text(title),
        ),
        body: SafeArea(
          top: false,
          child: ResponsiveContent(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BocSpace.gutter,
                    BocSpace.xs,
                    BocSpace.gutter,
                    0,
                  ),
                  child: Semantics(
                    label: 'Step ${_index + 1} of ${steps.length}',
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(BocRadius.pill),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        value: (_index + 1) / steps.length,
                        color: theme.brightness == Brightness.dark
                            ? BocColors.goldLight
                            : BocColors.navy,
                        backgroundColor: context.bocColors.border,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(BocSpace.gutter),
                    children: _stepBody(theme),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BocSpace.gutter,
                    0,
                    BocSpace.gutter,
                    BocSpace.md,
                  ),
                  child: Column(
                    children: [
                      PrimaryButton(
                        label: _step == _WizardStep.confirm
                            ? switch (widget.type) {
                                SavingsProductType.smartSave => 'Create goal',
                                SavingsProductType.fixed => 'Create deposit',
                                _ => 'Confirm & create',
                              }
                            : 'Continue',
                        isLoading: sending,
                        onPressed: _stepValid && !sending ? _next : null,
                      ),
                      if (failure != null) ...[
                        const SizedBox(height: BocSpace.xs),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            failure,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.bocColors.errorText,
                            ),
                          ),
                        ),
                      ],
                      if (_step == _WizardStep.confirm)
                        BocTextButton(
                          label: 'Go back and edit',
                          onPressed: sending ? null : back,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading(ThemeData theme, String text, [String? detail]) => Padding(
    padding: const EdgeInsets.only(bottom: BocSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(text, style: theme.textTheme.titleLarge),
        ),
        if (detail != null) ...[
          const SizedBox(height: BocSpace.xxs),
          Text(detail, style: theme.textTheme.bodyMedium),
        ],
      ],
    ),
  );

  Widget _label(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(top: BocSpace.md, bottom: BocSpace.xs),
    child: Text(text, style: theme.textTheme.labelMedium),
  );

  Widget _amountField(String label) => AppTextField(
    label: label,
    controller: _amount,
    hintText: '₦0.00',
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    inputFormatters: [ThousandsAmountFormatter()],
    autovalidateMode: widget.type == SavingsProductType.smartSave
        ? AutovalidateMode.onUserInteraction
        : null,
    validator: widget.type == SavingsProductType.smartSave
        ? (value) {
            final amount = value ?? '';
            if (savingsPlanNaira(amount) == null) {
              return 'Enter a valid target amount.';
            }
            if (!smartSaveTargetValid(amount)) {
              return 'Target amount must be above $_openingAmount.';
            }
            return null;
          }
        : null,
    onChanged: (value) => _update(_draft.copyWith(amount: value)),
  );

  List<Widget> _stepBody(ThemeData theme) {
    switch (_step) {
      case _WizardStep.goal:
        return [
          _heading(theme, 'What are you saving for?'),
          AppTextField(
            label: 'Goal name',
            controller: _name,
            hintText: 'e.g. New home 🏡',
            onChanged: (value) => _update(_draft.copyWith(name: value)),
          ),
          const SizedBox(height: BocSpace.md),
          _amountField('Target amount'),
          const SizedBox(height: BocSpace.md),
          SavingsCallout(
            icon: IconsaxPlusLinear.wallet_2,
            title: 'Minimum opening balance: $_openingAmount',
            body:
                'When you create this goal, we move this amount from '
                'Boc Flex Savings. Your target amount must be above '
                '$_openingAmount.',
          ),
        ];
      case _WizardStep.amount:
        return [
          _heading(
            theme,
            'How much do you want to lock?',
            'Your money earns a fixed rate until the end of the term.',
          ),
          _amountField('Amount'),
        ];
      case _WizardStep.schedule:
        return [
          _heading(
            theme,
            widget.type == SavingsProductType.fixed
                ? 'Choose a term'
                : 'How long will you save?',
          ),
          BocChoiceChips<int>(
            options: const [
              (value: 3, label: '3 months'),
              (value: 6, label: '6 months'),
              (value: 9, label: '9 months'),
              (value: 12, label: '12 months'),
            ],
            selected: {?_draft.durationMonths},
            onChanged: (value) => _update(
              _draft.copyWith(
                durationMonths: value.first,
                clearCustomMaturityDate: true,
              ),
            ),
          ),
          const SizedBox(height: BocSpace.md),
          InkWell(
            borderRadius: BorderRadius.circular(BocRadius.sm),
            onTap: _pickMaturityDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Custom maturity date',
                suffixIcon: Icon(IconsaxPlusLinear.calendar),
              ),
              child: Text(
                _draft.customMaturityDate == null
                    ? 'Choose a date'
                    : DateFormat(
                        'd MMM yyyy',
                      ).format(_draft.customMaturityDate!),
              ),
            ),
          ),
          const SizedBox(height: BocSpace.xs),
          Text(
            'Earliest date: '
            '${minimumSavingsTenorDays(widget.type)} days from today. '
            'Latest date: 1 year from today.',
            style: theme.textTheme.bodySmall,
          ),
          if (_createsInCore) ...[
            const SizedBox(height: BocSpace.md),
            SettingsGroup(
              padding: EdgeInsets.zero,
              children: [
                SettingsTile.toggle(
                  icon: IconsaxPlusLinear.repeat,
                  title: widget.type == SavingsProductType.fixed
                      ? 'Set recurring payments'
                      : 'Auto-save',
                  subtitle: widget.type == SavingsProductType.fixed
                      ? 'Add money to this deposit automatically'
                      : 'Save automatically on a schedule',
                  value: _draft.autoSave,
                  onChanged: (value) =>
                      _update(_draft.copyWith(autoSave: value)),
                ),
              ],
            ),
          ],
          const SizedBox(height: BocSpace.md),
          Text(
            widget.type == SavingsProductType.fixed
                ? 'Withdrawing before the end of the term pays your deposit '
                      'and the interest earned so far, minus an early '
                      'withdrawal fee. Your rate and maturity date show on '
                      'the deposit once it is created.'
                : 'Withdrawing before your target date pays your savings '
                      'and the interest earned so far, minus an early '
                      'withdrawal fee.',
            style: theme.textTheme.bodySmall,
          ),
          if (widget.type == SavingsProductType.fixed) ...[
            const SizedBox(height: BocSpace.md),
            SavingsCallout(
              icon: IconsaxPlusLinear.wallet_2,
              title: 'Minimum opening balance: $_openingAmount',
              body:
                  'When you create this deposit, we move this amount from '
                  'Boc Flex Savings.',
            ),
          ],
        ];
      case _WizardStep.days:
        final frequency = _draft.frequency;
        return [
          _heading(
            theme,
            widget.type == SavingsProductType.padi
                ? 'When do members contribute?'
                : 'How often should we save?',
          ),
          BocChoiceChips<SavingsFrequency>(
            options: [
              for (final value in SavingsFrequency.values)
                (value: value, label: value.label),
            ],
            selected: {?frequency},
            onChanged: (value) => _update(
              _draft.copyWith(frequency: value.first, contributionDays: {}),
            ),
          ),
          if (_createsInCore) ...[
            const SizedBox(height: BocSpace.md),
            AppTextField(
              label: 'Amount each time',
              controller: _recurring,
              hintText: '₦0.00',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [ThousandsAmountFormatter()],
              onChanged: (value) =>
                  _update(_draft.copyWith(recurringAmount: value)),
            ),
          ],
          // Core has no contribution days; only Padi picks them.
          if (!_createsInCore && frequency == SavingsFrequency.weekly) ...[
            _label(theme, 'Day of the week'),
            BocChoiceChips<int>(
              multiSelect: widget.type == SavingsProductType.padi,
              options: const [
                (value: 1, label: 'Mon'),
                (value: 2, label: 'Tue'),
                (value: 3, label: 'Wed'),
                (value: 4, label: 'Thu'),
                (value: 5, label: 'Fri'),
                (value: 6, label: 'Sat'),
                (value: 7, label: 'Sun'),
              ],
              selected: _draft.contributionDays,
              onChanged: (value) =>
                  _update(_draft.copyWith(contributionDays: value)),
            ),
          ],
          if (!_createsInCore && frequency == SavingsFrequency.monthly) ...[
            _label(theme, 'Day of the month'),
            BocChoiceChips<int>(
              options: const [
                (value: 1, label: '1st'),
                (value: 15, label: '15th'),
                (value: 28, label: '28th'),
              ],
              selected: _draft.contributionDays,
              onChanged: (value) =>
                  _update(_draft.copyWith(contributionDays: value)),
            ),
          ],
        ];
      case _WizardStep.padiGroup:
        final members = _draft.memberCount ?? 2;
        return [
          _heading(theme, 'Set up your Padi group'),
          AppTextField(
            label: 'Group name',
            controller: _name,
            hintText: 'e.g. Office rent circle',
            onChanged: (value) => _update(_draft.copyWith(name: value)),
          ),
          _label(theme, 'Number of members'),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'Fewer members',
                onPressed: members > 2
                    ? () => _update(_draft.copyWith(memberCount: members - 1))
                    : null,
                icon: const Icon(IconsaxPlusLinear.minus),
              ),
              Expanded(
                child: Text(
                  '$members',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.figures,
                ),
              ),
              IconButton.outlined(
                tooltip: 'More members',
                onPressed: members < 20
                    ? () => _update(_draft.copyWith(memberCount: members + 1))
                    : null,
                icon: const Icon(IconsaxPlusLinear.add),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.md),
          _amountField('Contribution per member'),
        ];
      case _WizardStep.start:
        final start = _draft.startDate;
        return [
          _heading(
            theme,
            'When does the first round start?',
            'Each round, every member contributes and one member, in turn '
                'order, receives the full pot. The cycle closes once everyone '
                'has been paid.',
          ),
          InkWell(
            borderRadius: BorderRadius.circular(BocRadius.sm),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: now,
                lastDate: DateTime(now.year + 1, now.month, now.day),
                initialDate: start ?? now,
              );
              if (picked != null) _update(_draft.copyWith(startDate: picked));
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Start date',
                suffixIcon: Icon(IconsaxPlusLinear.calendar),
              ),
              child: Text(
                start == null
                    ? 'Choose a date'
                    : DateFormat('d MMM yyyy').format(start),
              ),
            ),
          ),
        ];
      case _WizardStep.confirm:
        final fixed = widget.type == SavingsProductType.fixed;
        final frequency = _draft.autoSave ? _draft.frequency : null;
        if (widget.type == SavingsProductType.smartSave || fixed) {
          final months = _draft.durationMonths;
          final customDate = _draft.customMaturityDate;
          final recurring = formatApiAmount(
            savingsPlanNaira(_draft.recurringAmount),
            currency: 'NGN',
          );
          return [
            _heading(
              theme,
              fixed ? 'Review your deposit' : 'Review your goal',
              'Check the details before you create it.',
            ),
            if (fixed) ...[
              AppTextField(
                label: 'Deposit name (optional)',
                controller: _name,
                hintText: 'e.g. School fees 🎓',
                onChanged: (value) => _update(_draft.copyWith(name: value)),
              ),
              const SizedBox(height: BocSpace.md),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(BocSpace.lg),
                decoration: BoxDecoration(
                  color: context.bocColors.smartSaveContainer,
                  borderRadius: BorderRadius.circular(BocRadius.lg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_draft.name.trim().isNotEmpty) ...[
                      Text(
                        _draft.name.trim(),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: BocSpace.xxs),
                    ],
                    Text(
                      'Target',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.bocColors.textSecondary,
                      ),
                    ),
                    Text(
                      formatApiAmount(
                            savingsPlanNaira(_draft.amount),
                            currency: 'NGN',
                          ) ??
                          '₦${_draft.amount}',
                      style: theme.textTheme.headlineMedium?.figures,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BocSpace.md),
            ],
            SavingsFactGroup(
              title: fixed ? 'Deposit details' : 'Saving plan',
              rows: [
                if (months != null)
                  (label: 'Duration', value: '$months months'),
                if (customDate != null) ...[
                  (
                    label: 'Duration',
                    value: '${_draft.tenorDaysOn(DateTime.now())} days',
                  ),
                  (
                    label: 'Target maturity date',
                    value: DateFormat('d MMM yyyy').format(customDate),
                  ),
                ],
                if (fixed)
                  (
                    label: 'Recurring payments',
                    value: frequency != null && recurring != null
                        ? '$recurring ${frequency.label.toLowerCase()}'
                        : 'Not set',
                  )
                else
                  (
                    label: 'Auto-save',
                    value: frequency != null && recurring != null
                        ? '$recurring ${frequency.label.toLowerCase()}'
                        : 'Manual deposits',
                  ),
              ],
            ),
            if (_createsInCore) ...[
              const SizedBox(height: BocSpace.md),
              SavingsCallout(
                icon: IconsaxPlusLinear.wallet_2,
                title: '$_openingAmount from Boc Flex Savings',
                body:
                    'Creating this $_planKind moves the minimum opening '
                    'balance from Boc Flex Savings into your new plan.',
              ),
            ],
          ];
        }
        return [
          _heading(
            theme,
            'Confirm your ${widget.type.displayName}',
            'Double-check the details before you create it.',
          ),
          if (fixed) ...[
            AppTextField(
              label: 'Deposit name (optional)',
              controller: _name,
              hintText: 'e.g. School fees 🎓',
              onChanged: (value) => _update(_draft.copyWith(name: value)),
            ),
            const SizedBox(height: BocSpace.md),
          ],
          BocSummaryGrid(
            items: [
              if (!fixed && _draft.name.trim().isNotEmpty)
                (label: 'Name', value: _draft.name.trim()),
              if (!fixed)
                (
                  label: widget.type == SavingsProductType.padi
                      ? 'Contribution'
                      : 'Target amount',
                  value: '₦${_draft.amount}',
                ),
              if (_draft.durationMonths != null)
                (label: 'Duration', value: '${_draft.durationMonths} months'),
              if (frequency != null)
                (label: 'Frequency', value: frequency.label),
              if (frequency != null && _createsInCore)
                (
                  label: 'Amount each time',
                  value: '₦${_draft.recurringAmount}',
                ),
              if (_draft.memberCount != null)
                (label: 'Members', value: '${_draft.memberCount}'),
              if (_draft.startDate != null)
                (
                  label: 'Starts',
                  value: DateFormat('d MMM yyyy').format(_draft.startDate!),
                ),
            ],
          ),
          if (_createsInCore) ...[
            const SizedBox(height: BocSpace.md),
            Text(
              'Funded from Boc Flex Savings',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: BocSpace.xxs),
            Text(
              "We'll move the minimum for this term from Boc Flex Savings now.",
              style: theme.textTheme.bodySmall,
            ),
          ],
        ];
    }
  }
}
