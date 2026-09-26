part of '../../app_flow/app_flow_navigator.dart';

extension SavingsScreens on AppFlowNavigatorState {
  Future<void> _refreshSavings() async {
    await ref.read(userHomeProvider.notifier).load();
  }

  List<Widget> _savingsLoadStatus(NotifierState<UserHomeData> home) => [
    if (home.isLoading || home.status == ServiceStatus.idle) ...[
      const LinearProgressIndicator(),
      const SizedBox(height: 12),
      Text(
        home.data == null
            ? 'Loading account details…'
            : 'Refreshing account details…',
      ),
      const SizedBox(height: 12),
    ],
    if (home.isError) ...[
      ApiStateCard(
        title: home.data == null
            ? 'Unable to load account details'
            : 'Refresh failed',
        message: home.data == null
            ? 'Please try again to load your account details.'
            : 'Showing previously loaded details. Refresh to check for updates.',
        tone: ApiStateTone.warning,
        actionLabel: 'Retry',
        onAction: _refreshSavings,
      ),
      const SizedBox(height: 12),
    ],
  ];

  Widget _savingsRefreshAction(NotifierState<UserHomeData> home) => IconButton(
    tooltip: 'Refresh',
    onPressed: home.isLoading ? null : _refreshSavings,
    icon: const Icon(Icons.refresh_rounded),
  );

  Widget _saveHubScreen() {
    final home = ref.watch(userHomeProvider);
    final products = ref.watch(savingsProductsProvider);
    final flexProduct = products.where((p) => p.canOpenFlex).firstOrNull;
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Save',
      activeSection: AppSection.save,
      onSectionSelected: _goSection,
      actions: [_savingsRefreshAction(home)],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xxs,
            BocSpace.gutter,
            BocSpace.lg,
          ),
          children: [
            ..._savingsLoadStatus(home),
            if (flexProduct != null)
              FlexSavingsTile(
                title: flexProduct.name,
                balance: formatApiAmount(
                  home.data?.flexWallet?.availableBalance,
                  currency: home.data?.flexWallet?.currency,
                ),
                hidden: ref.watch(homeBalanceHiddenProvider),
                onTap: () => _go(AppScreen.flex),
              )
            else if (home.isDone || home.data != null)
              const ApiStateCard(
                title: 'Product catalogue unavailable',
                message: 'Savings products will appear here when available.',
                tone: ApiStateTone.info,
              ),
            const SizedBox(height: BocSpace.lg),
            Semantics(
              header: true,
              child: Text('Choose a plan', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: BocSpace.sm),
            SizedBox(
              height: 168,
              child: ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                children: [
                  for (final (type, icon, description) in const [
                    (
                      SavingsProductType.smartSave,
                      Icons.track_changes_rounded,
                      'Daily, weekly or monthly auto-save toward a goal',
                    ),
                    (
                      SavingsProductType.fixed,
                      Icons.lock_outline_rounded,
                      'Fixed term, higher rate, locked until maturity',
                    ),
                    (
                      SavingsProductType.padi,
                      Icons.groups_outlined,
                      'Save with friends and take turns receiving the pot',
                    ),
                  ]) ...[
                    PlanTypeCard(
                      title: type.displayName,
                      description: description,
                      icon: icon,
                      accent: _productAccent(type),
                      container: switch (type) {
                        SavingsProductType.fixed =>
                          context.bocColors.fixedContainer,
                        SavingsProductType.padi =>
                          context.bocColors.padiContainer,
                        _ => context.bocColors.smartSaveContainer,
                      },
                      onTap: () => _startPlanCreation(type),
                    ),
                    const SizedBox(width: BocSpace.sm),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens a product's creation wizard, or explains that it is not
  /// available yet.
  Future<void> _startPlanCreation(SavingsProductType type) async {
    final capability = type.createCapability;
    if (capability == null ||
        !ref.read(featureAvailabilityProvider(capability)).isAvailable) {
      await BocUnavailableSheet.show(
        context,
        title: '${type.displayName} is not available yet',
      );
    }
  }

  Widget _addMoneyScreen() {
    final home = ref.watch(userHomeProvider);
    return AppScaffold(
      title: 'Add money',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      actions: [_savingsRefreshAction(home)],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            ..._savingsLoadStatus(home),
            if (home.data != null || home.isDone)
              _dedicatedVirtualAccountCard(home.data?.dedicatedVirtualAccount),
          ],
        ),
      ),
    );
  }

  Widget _flexScreen() {
    final home = ref.watch(userHomeProvider);
    final wallet = home.data?.flexWallet;
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final canWithdraw = ref
        .watch(featureAvailabilityProvider(FeatureCapability.flexWithdraw))
        .isAvailable;
    final ledger = formatApiAmount(
      wallet?.ledgerBalance,
      currency: wallet?.currency,
    );
    final status = wallet?.status;
    return AppScaffold(
      title: 'Boc Flex Savings',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      actions: [_savingsRefreshAction(home)],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            0,
            BocSpace.gutter,
            BocSpace.lg,
          ),
          children: [
            ..._savingsLoadStatus(home),
            if (home.data != null || home.isDone)
              FlexHeroCard(
                balance: formatApiAmount(
                  wallet?.availableBalance,
                  currency: wallet?.currency,
                ),
                hidden: hidden,
                onToggle: () =>
                    ref.read(homeBalanceHiddenProvider.notifier).toggle(),
                primary: PrimaryButton(
                  label: 'Add money',
                  onPressed: () => _go(AppScreen.addMoney),
                ),
                secondary: canWithdraw
                    ? SecondaryButton(label: 'Withdraw', onPressed: () {})
                    : null,
              ),
            if (ledger != null ||
                (status != null && wallet?.isActive == false)) ...[
              const SizedBox(height: BocSpace.sm),
              GridViewInfo(
                items: [
                  if (ledger != null)
                    (
                      label: 'Ledger balance',
                      value: hidden ? '₦ ••••••' : ledger,
                    ),
                  if (status != null && wallet?.isActive == false)
                    (label: 'Wallet status', value: status),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _savingsUnavailableScreen({
    required FeatureCapability capability,
    required String title,
    required String message,
  }) {
    _assertPlaceholderFor(capability, FeatureAvailability.unavailable);
    return AppScaffold(
      title: title,
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ApiStateCard(
            title: 'Unavailable',
            message: message,
            tone: ApiStateTone.blocked,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _go(AppScreen.saveHub),
            child: const Text('Back to Savings'),
          ),
        ],
      ),
    );
  }

  Widget _targetScreen() => _savingsUnavailableScreen(
    capability: FeatureCapability.savingsPlansView,
    title: 'Target Savings',
    message: 'Target Savings is unavailable in this release.',
  );
  Widget _lockScreen() => _savingsUnavailableScreen(
    capability: FeatureCapability.savingsPlansView,
    title: 'Fixed Deposit',
    message: 'Fixed Deposit is unavailable in this release.',
  );
  Widget _groupScreen() => _savingsUnavailableScreen(
    capability: FeatureCapability.savingsPlansView,
    title: 'Group Savings',
    message: 'Group Savings is unavailable in this release.',
  );
}
