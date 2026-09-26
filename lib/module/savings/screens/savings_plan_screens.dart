part of '../../app_flow/app_flow_navigator.dart';

/// Plan detail and management. Everything shown comes from the plans
/// provider; with no server plan the screen explains the gap. Deposit, edit
/// and withdraw are each gated by their own capability.
extension SavingsPlanScreens on AppFlowNavigatorState {
  Color _productAccent(SavingsProductType type) {
    final colors = context.bocColors;
    return switch (type) {
      SavingsProductType.flex => colors.flexAccent,
      SavingsProductType.smartSave => colors.smartSaveAccent,
      SavingsProductType.fixed => colors.fixedAccent,
      SavingsProductType.padi => colors.padiAccent,
    };
  }

  Widget _savingsPlanDetailScreen() {
    final planId = widget.routeArguments.entityId;
    final plans = ref.watch(savingsPlansProvider);
    final plan = plans.data
        ?.where((candidate) => candidate.id == planId)
        .firstOrNull;
    if (plan == null) {
      return AppScaffold(
        title: 'Savings plan',
        activeSection: AppSection.save,
        onBack: _back,
        onSectionSelected: _goSection,
        body: ListView(
          padding: const EdgeInsets.all(BocSpace.gutter),
          children: [
            ApiStateCard(
              title: 'Savings plans are not available yet',
              message:
                  plans.message ??
                  'Your SmartSave, Fixed Deposit and Padi plans will '
                      'appear here.',
              tone: ApiStateTone.blocked,
            ),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final rate = plan.rate;
    final progress = plan.progress;
    final target = plan.target;
    return AppScaffold(
      title: plan.name,
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
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
            child: ListView(
              padding: const EdgeInsets.all(BocSpace.gutter),
              children: [
                BocMoneyText(plan.balance, semanticsLabel: 'Plan balance'),
                if (rate != null) ...[
                  const SizedBox(height: BocSpace.xxs),
                  Text(
                    '$rate per annum',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.bocColors.blueStrong,
                    ),
                  ),
                ],
                if (progress != null && target != null) ...[
                  const SizedBox(height: BocSpace.lg),
                  Container(
                    padding: const EdgeInsets.all(BocSpace.md),
                    decoration: BoxDecoration(
                      color: context.bocColors.surface,
                      borderRadius: BorderRadius.circular(BocRadius.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target', style: theme.textTheme.titleMedium),
                        const SizedBox(height: BocSpace.sm),
                        BocProgressArc(
                          progress: progress,
                          targetLabel: target,
                          color: _productAccent(plan.type),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ),
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
    final penalty = plan.earlyWithdrawalPenalty;
    final matured = plan.status == SavingsPlanStatus.matured;
    await AppConfirmSheet.show(
      context,
      title: 'Withdraw?',
      message: matured || penalty == null
          ? 'Your money will move to your BOCTRUST wallet.'
          : 'Withdrawing before your target date means $penalty',
      confirmLabel: matured ? 'Withdraw' : 'Withdraw and forfeit interest',
      cancelLabel: 'Keep saving',
      destructive: !matured,
    );
  }
}
