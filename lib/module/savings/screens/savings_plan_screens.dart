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

  String _planMoney(String? naira) => ref.watch(homeBalanceHiddenProvider)
      ? '₦ ••••••'
      : formatApiAmount(naira, currency: 'NGN') ?? 'Unavailable';

  /// One product's plans, as Core groups them, with the product balance.
  Widget _savingsPlansScreen(SavingsProductType type, String title) {
    final state = ref.watch(savingsPlansProvider(type));
    final theme = Theme.of(context);
    return AppScaffold(
      title: title,
      activeSection: AppSection.save,
      onBack: back,
      onSectionSelected: goSection,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(savingsPlansProvider(type).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xxs,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: switch (state) {
            AsyncData(:final value)
                when value.data != null ||
                    value.status == ServiceStatus.empty =>
              switch (value.data
                  ?.where((group) => group.type == type)
                  .firstOrNull) {
                final group? when group.plans.isNotEmpty => [
                  SurfaceCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.productName,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: BocSpace.xxs),
                        BocMoneyText(
                          _planMoney(group.balance),
                          semanticsLabel: 'Product balance',
                        ),
                        if (group.rate case final rate?)
                          Text('$rate% p.a.', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  for (final plan in group.plans) ...[
                    const SizedBox(height: BocSpace.sm),
                    _planTile(plan),
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
      ),
    );
  }

  Widget _planTile(SavingsPlan plan) {
    final theme = Theme.of(context);
    final maturity = plan.maturityDate;
    return SurfaceCard(
      onTap: () => go(
        AppRoutes.savingsPlanDetail,
        arguments: AppRouteArguments(entityId: plan.id),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.name, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  _planMoney(plan.principal),
                  style: theme.textTheme.bodyMedium,
                ),
                if (maturity != null)
                  Text(
                    'Matures ${DateFormat('d MMM yyyy').format(maturity)}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(plan.status.label, style: theme.textTheme.labelMedium),
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
    String date(DateTime value) => DateFormat('d MMM yyyy').format(value);
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
            _ => _withdrawFromPlan(plan),
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit plan')),
            PopupMenuItem(value: 'withdraw', child: Text('Withdraw')),
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
                padding: const EdgeInsets.all(BocSpace.gutter),
                children: [
                  BocMoneyText(
                    _planMoney(plan.principal),
                    semanticsLabel: 'Plan balance',
                  ),
                  if (rate != null) ...[
                    const SizedBox(height: BocSpace.xxs),
                    Text(
                      '$rate% per annum',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.bocColors.blueStrong,
                      ),
                    ),
                  ],
                  const SizedBox(height: BocSpace.lg),
                  BocSummaryGrid(
                    items: [
                      (label: 'Status', value: plan.status.label),
                      if (plan.target case final target?)
                        (label: 'Target', value: _planMoney(target)),
                      if (plan.interestEarned case final interest?)
                        (label: 'Interest earned', value: _planMoney(interest)),
                      if (plan.tenorDays case final days?)
                        (label: 'Tenor', value: '$days days'),
                      if (plan.maturityDate case final maturity?)
                        (label: 'Matures', value: date(maturity)),
                    ],
                  ),
                  if (detail.events.isNotEmpty) ...[
                    const SizedBox(height: BocSpace.lg),
                    Semantics(
                      header: true,
                      child: Text(
                        'Activity',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    for (final event in detail.events)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(event.type.label),
                        subtitle: event.createdAt == null
                            ? null
                            : Text(date(event.createdAt!.toLocal())),
                        trailing: event.amount == null
                            ? null
                            : Text(_planMoney(event.amount)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            // The list above stops at this footer, so the footer itself
            // has to clear the floating nav pill.
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ).clearOfNav(context),
            child: PrimaryButton(
              label: 'Deposit',
              onPressed: () =>
                  _gatedPlanAction(FeatureCapability.savingsPlanDeposit),
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

  /// Early withdrawal forfeits interest, so it needs an explicit, clearly
  /// labelled confirmation; the safe choice is the prominent one.
  Future<void> _withdrawFromPlan(SavingsPlan plan) async {
    if (!ref
        .read(
          featureAvailabilityProvider(FeatureCapability.savingsPlanWithdraw),
        )
        .isAvailable) {
      await BocUnavailableSheet.show(context);
      return;
    }
    final matured = plan.status == SavingsPlanStatus.matured;
    await AppConfirmSheet.show(
      context,
      title: 'Withdraw?',
      message: matured
          ? 'Your money will move to Boc Flex Savings.'
          : 'Withdrawing early returns your full principal to Boc Flex '
                'Savings without interest.',
      confirmLabel: matured ? 'Withdraw' : 'Withdraw and forfeit interest',
      cancelLabel: 'Keep saving',
      destructive: !matured,
    );
  }
}

/// One wizard for every savings product: each type contributes its steps,
/// all steps edit one [SavingsPlanDraft], and the draft stays on the device.
/// The final "Confirm & create" is gated by the product's create capability,
/// so no "created" screen can appear until the server confirms a plan.
class _SavingsPlanWizard extends ConsumerStatefulWidget {
  const _SavingsPlanWizard({required this.type, required this.onExit});

  final SavingsProductType type;
  final VoidCallback onExit;

  @override
  ConsumerState<_SavingsPlanWizard> createState() => _SavingsPlanWizardState();
}

enum _WizardStep {
  goal,
  amount,
  schedule,
  days,
  funding,
  padiGroup,
  start,
  confirm,
}

class _SavingsPlanWizardState extends ConsumerState<_SavingsPlanWizard> {
  late SavingsPlanDraft _draft = SavingsPlanDraft(type: widget.type);
  int _index = 0;
  final _name = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  List<_WizardStep> get _steps => switch (widget.type) {
    SavingsProductType.smartSave => [
      _WizardStep.goal,
      _WizardStep.schedule,
      if (_draft.autoSave) _WizardStep.days,
      _WizardStep.funding,
      _WizardStep.confirm,
    ],
    SavingsProductType.fixed => [
      _WizardStep.amount,
      _WizardStep.schedule,
      _WizardStep.funding,
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

  bool get _amountValid {
    final value = num.tryParse(_draft.amount.replaceAll(',', ''));
    return value != null && value > 0;
  }

  bool get _stepValid => switch (_step) {
    _WizardStep.goal => _draft.name.trim().isNotEmpty && _amountValid,
    _WizardStep.amount => _amountValid,
    _WizardStep.schedule => _draft.durationMonths != null,
    _WizardStep.days =>
      _draft.frequency != null &&
          (_draft.frequency == SavingsFrequency.daily ||
              _draft.contributionDays.isNotEmpty),
    _WizardStep.funding => _draft.fundingSource != null,
    _WizardStep.padiGroup =>
      _draft.name.trim().isNotEmpty &&
          (_draft.memberCount ?? 0) >= 2 &&
          _amountValid,
    _WizardStep.start => _draft.startDate != null,
    _WizardStep.confirm => true,
  };

  void _update(SavingsPlanDraft next) => setState(() => _draft = next);

  void back() {
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
    final capability = widget.type.createCapability;
    if (capability == null ||
        !ref.read(featureAvailabilityProvider(capability)).isAvailable) {
      await BocUnavailableSheet.show(
        context,
        title: '${widget.type.displayName} is not available yet',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _steps;
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
                            ? 'Confirm & create'
                            : 'Continue',
                        onPressed: _stepValid ? _next : null,
                      ),
                      if (_step == _WizardStep.confirm)
                        BocTextButton(
                          label: 'Go back and edit',
                          onPressed: back,
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
            hintText: 'e.g. Rent',
            onChanged: (value) => _update(_draft.copyWith(name: value)),
          ),
          const SizedBox(height: BocSpace.md),
          _amountField('Target amount'),
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
            onChanged: (value) =>
                _update(_draft.copyWith(durationMonths: value.first)),
          ),
          if (widget.type == SavingsProductType.smartSave) ...[
            const SizedBox(height: BocSpace.md),
            SettingsGroup(
              padding: EdgeInsets.zero,
              children: [
                SettingsTile.toggle(
                  icon: IconsaxPlusLinear.repeat,
                  title: 'Auto-save',
                  subtitle: 'Save automatically on a schedule',
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
                ? 'Withdrawing before the end of the term may forfeit '
                      'interest. Your rate and maturity date are confirmed '
                      'before you create the deposit.'
                : 'Withdrawing before your target date may forfeit part of '
                      'the interest you have earned.',
            style: theme.textTheme.bodySmall,
          ),
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
          if (frequency == SavingsFrequency.weekly) ...[
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
          if (frequency == SavingsFrequency.monthly) ...[
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
      case _WizardStep.funding:
        return [
          _heading(theme, 'Where should the money come from?'),
          for (final source in FundingSource.values)
            Padding(
              padding: const EdgeInsets.only(bottom: BocSpace.xs),
              child: SelectableMethodTile(
                icon: switch (source) {
                  FundingSource.wallet => IconsaxPlusLinear.wallet,
                  FundingSource.flexSavings => BocIcons.savings,
                  FundingSource.bankTransfer => IconsaxPlusLinear.bank,
                },
                title: source.label,
                subtitle: '',
                selected: _draft.fundingSource == source,
                onTap: () => _update(_draft.copyWith(fundingSource: source)),
              ),
            ),
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
        final frequency = _draft.frequency;
        return [
          _heading(
            theme,
            'Confirm your ${widget.type.displayName}',
            'Double-check the details before you create it.',
          ),
          BocSummaryGrid(
            items: [
              if (_draft.name.trim().isNotEmpty)
                (label: 'Name', value: _draft.name.trim()),
              (
                label: switch (widget.type) {
                  SavingsProductType.padi => 'Contribution',
                  SavingsProductType.fixed => 'Amount',
                  _ => 'Target amount',
                },
                value: '₦${_draft.amount}',
              ),
              if (_draft.durationMonths != null)
                (label: 'Duration', value: '${_draft.durationMonths} months'),
              if (frequency != null)
                (label: 'Frequency', value: frequency.label),
              if (_draft.memberCount != null)
                (label: 'Members', value: '${_draft.memberCount}'),
              if (_draft.fundingSource != null)
                (label: 'Funded from', value: _draft.fundingSource!.label),
              if (_draft.startDate != null)
                (
                  label: 'Starts',
                  value: DateFormat('d MMM yyyy').format(_draft.startDate!),
                ),
            ],
          ),
        ];
    }
  }
}
