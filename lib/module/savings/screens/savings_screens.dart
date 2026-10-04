part of '../../app_flow/app_flow_navigator.dart';

extension SavingsScreens on AppFlowNavigatorState {
  Future<void> _refreshSavings() async {
    await Future.wait([
      ref.read(userHomeProvider.notifier).load(),
      ref.read(customerBankAccountsProvider.notifier).load(),
      ref.read(coreBankProductsProvider.notifier).load(),
    ]);
  }

  /// Starts the Core account and product reads the first time a savings
  /// screen needs them.
  NotifierState<CustomerBankAccountsData> _watchCoreAccounts() {
    final accounts = ref.watch(customerBankAccountsProvider);
    if (accounts.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(
        ref.read(customerBankAccountsProvider.notifier).load,
      );
    }
    return accounts;
  }

  /// The User Service Home aggregate, whose Flex wallet and catalogue cover
  /// customers Core has not opened accounts for yet.
  NotifierState<UserHomeData> _watchUserHome() {
    final home = ref.watch(userHomeProvider);
    if (home.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(ref.read(userHomeProvider.notifier).load);
    }
    return home;
  }

  NotifierState<List<CoreBankProduct>> _watchCoreProducts() {
    final products = ref.watch(coreBankProductsProvider);
    if (products.status == ServiceStatus.idle &&
        ref.read(authSessionProvider) != null) {
      Future<void>.microtask(ref.read(coreBankProductsProvider.notifier).load);
    }
    return products;
  }

  /// Loading and failure notice for the Core balances. A failed refresh keeps
  /// the last good balances visible beside it.
  List<Widget> _coreAccountsStatus(
    NotifierState<CustomerBankAccountsData> accounts,
  ) => [
    if (accounts.data == null &&
        (accounts.isLoading || accounts.status == ServiceStatus.idle)) ...[
      const LinearProgressIndicator(),
      const SizedBox(height: 12),
      const Text('Loading your accounts…'),
      const SizedBox(height: 12),
    ],
    if (accounts.isError || accounts.status == ServiceStatus.blocked) ...[
      ApiStateCard(
        title: accounts.data == null
            ? 'Unable to load your accounts'
            : 'Refresh failed',
        message: accounts.data == null
            ? accounts.message ?? 'Please try again to load your accounts.'
            : 'Showing previously loaded balances. Refresh to check for '
                  'updates.',
        tone: ApiStateTone.warning,
        actionLabel: 'Retry',
        onAction: _refreshSavings,
      ),
      const SizedBox(height: 12),
    ],
  ];

  String _accountStatusLabel(CoreAccountStatus status) => switch (status) {
    CoreAccountStatus.active => 'Active',
    CoreAccountStatus.frozen => 'Frozen',
    CoreAccountStatus.closed => 'Closed',
    CoreAccountStatus.unknown => 'Unavailable',
  };

  /// One owned Core account other than Flex: name, balance and server status.
  Widget _coreAccountTile(CustomerBankAccount account, {required bool hidden}) {
    final theme = Theme.of(context);
    final balance = formatApiAmount(account.availableBalance, currency: 'NGN');
    return SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.productName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  hidden ? '₦ ••••••' : balance ?? 'Balance unavailable',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (!account.isActive)
            Text(
              _accountStatusLabel(account.status),
              style: theme.textTheme.labelMedium,
            ),
        ],
      ),
    );
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
    final accountsState = _watchCoreAccounts();
    final productsState = _watchCoreProducts();
    final homeState = _watchUserHome();
    final accounts = accountsState.data;
    final flex = resolveFlexBalance(
      core: accounts,
      wallet: homeState.data?.flexWallet,
    );
    final userCatalogue = CoreBankProduct.listFromJson(
      homeState.data?.savingsProducts ?? const [],
    );
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final otherAccounts = [
      for (final account in accounts?.accounts ?? const <CustomerBankAccount>[])
        if (account.productCode != kFlexProductCode) account,
    ];
    final ownedCodes = {
      for (final account in accounts?.accounts ?? const <CustomerBankAccount>[])
        account.productCode,
      if (flex != null) kFlexProductCode,
    };
    // Core's catalogue when it has one, otherwise the User Service catalogue.
    // Account opening is out of scope, so unowned products are read-only.
    final catalogue = (productsState.data?.isNotEmpty ?? false)
        ? productsState.data!
        : userCatalogue;
    final unowned = [
      for (final product in catalogue)
        if (!ownedCodes.contains(product.code)) product,
    ];
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Save',
      activeSection: AppSection.save,
      onSectionSelected: _goSection,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: accountsState.isLoading ? null : _refreshSavings,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xxs,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: [
            // Core problems only matter while Core is the balance source.
            if (flex?.isCoreAccount ?? true)
              ..._coreAccountsStatus(accountsState),
            if (flex != null)
              FlexSavingsTile(
                title:
                    flex.productName ??
                    userCatalogue
                        .where((p) => p.code == kFlexProductCode)
                        .firstOrNull
                        ?.name ??
                    'Boc Flex Savings',
                balance: formatApiAmount(
                  flex.availableBalance,
                  currency: 'NGN',
                ),
                hidden: hidden,
                onTap: () => _go(AppScreen.flex),
              )
            else if (accounts != null || homeState.data != null)
              const ApiStateCard(
                title: 'Flex account unavailable',
                message: 'Your Flex account will appear here when available.',
                tone: ApiStateTone.info,
              ),
            for (final account in otherAccounts) ...[
              const SizedBox(height: BocSpace.sm),
              _coreAccountTile(account, hidden: hidden),
            ],
            if (unowned.isNotEmpty) ...[
              const SizedBox(height: BocSpace.lg),
              Semantics(
                header: true,
                child: Text(
                  'Available products',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final product in unowned) ...[
                const SizedBox(height: BocSpace.sm),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name, style: theme.textTheme.titleSmall),
                      if (product.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
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

  bool _canCreatePlan(SavingsProductType type) {
    final capability = type.createCapability;
    return capability != null &&
        ref.read(featureAvailabilityProvider(capability)).isAvailable;
  }

  /// Opens a product's creation wizard once it can be created; until then
  /// the customer learns that up front instead of after filling a form.
  Future<void> _startPlanCreation(SavingsProductType type) async {
    if (!_canCreatePlan(type)) {
      await BocUnavailableSheet.show(
        context,
        title: '${type.displayName} is not available yet',
      );
      return;
    }
    _go(switch (type) {
      SavingsProductType.fixed => AppScreen.fixedDepositCreate,
      SavingsProductType.padi => AppScreen.padiCreate,
      _ => AppScreen.smartSaveCreate,
    });
  }

  /// Deep links to a create route show the wizard only for a product that
  /// can be created.
  Widget _planCreationScreen(SavingsProductType type) {
    if (_canCreatePlan(type)) {
      return _SavingsPlanWizard(type: type, onExit: _back);
    }
    return _savingsUnavailableScreen(
      capability: type.createCapability!,
      title: type.displayName,
      message: '${type.displayName} is not available yet.',
    );
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
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
    final accountsState = _watchCoreAccounts();
    final homeState = _watchUserHome();
    final flex = resolveFlexBalance(
      core: accountsState.data,
      wallet: homeState.data?.flexWallet,
    );
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final canWithdraw = ref
        .watch(featureAvailabilityProvider(FeatureCapability.flexWithdraw))
        .isAvailable;
    final ledger = formatApiAmount(flex?.ledgerBalance, currency: 'NGN');
    // A Core Flex account refreshes on its own; the User wallet needs Home.
    final coreAccountNumber = flex?.accountNumber;
    Future<void> refresh() => coreAccountNumber == null
        ? _refreshSavings()
        : ref
              .read(customerBankAccountsProvider.notifier)
              .refreshAccount(coreAccountNumber);
    return AppScaffold(
      title: 'Boc Flex Savings',
      activeSection: AppSection.save,
      onBack: _back,
      onSectionSelected: _goSection,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: accountsState.isLoading ? null : refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            0,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: [
            if (flex?.isCoreAccount ?? true)
              ..._coreAccountsStatus(accountsState),
            if ((accountsState.data != null || homeState.data != null) &&
                flex == null)
              const ApiStateCard(
                title: 'Flex account unavailable',
                message:
                    'Your Flex account is unavailable right now. Refresh to '
                    'try again.',
                tone: ApiStateTone.info,
              ),
            if (flex != null)
              FlexHeroCard(
                balance: formatApiAmount(
                  flex.availableBalance,
                  currency: 'NGN',
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
            // Only an active Flex account is shown, so no status row is needed.
            if (flex != null && ledger != null) ...[
              const SizedBox(height: BocSpace.sm),
              GridViewInfo(
                items: [
                  (
                    label: 'Ledger balance',
                    value: hidden ? '₦ ••••••' : ledger,
                  ),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
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
