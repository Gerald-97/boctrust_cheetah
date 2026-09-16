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
    return AppScaffold(
      title: 'Savings',
      activeSection: AppSection.save,
      onSectionSelected: _goSection,
      actions: [_savingsRefreshAction(home)],
      body: RefreshIndicator(
        onRefresh: _refreshSavings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            ..._savingsLoadStatus(home),
            if (home.data != null || home.isDone)
              _flexWalletCard(home.data?.flexWallet, loading: home.isLoading),
            const SizedBox(height: 20),
            Text(
              'Savings products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (products.isEmpty)
              const ApiStateCard(
                title: 'Product catalogue unavailable',
                message: 'Savings products will appear here when available.',
                tone: ApiStateTone.info,
              ),
            for (final product in products)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SurfaceCard(
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.savings_outlined),
                      title: Text(product.name),
                      subtitle: Text(
                        product.canOpenFlex
                            ? 'View your Flex wallet'
                            : 'Unavailable in this release',
                      ),
                      trailing: product.canOpenFlex
                          ? const Icon(Icons.chevron_right_rounded)
                          : null,
                      onTap: product.canOpenFlex
                          ? () => _go(AppScreen.flex)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
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
    return AppScaffold(
      title: 'Flex Savings',
      activeSection: AppSection.save,
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
              _flexWalletCard(home.data?.flexWallet, loading: home.isLoading),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Add money',
              onPressed: () => _go(AppScreen.addMoney),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savingsUnavailableScreen({
    required String title,
    required String message,
  }) => AppScaffold(
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

  Widget _targetScreen() => _savingsUnavailableScreen(
    title: 'Target Savings',
    message: 'Target Savings is unavailable in this release.',
  );
  Widget _lockScreen() => _savingsUnavailableScreen(
    title: 'Fixed Deposit',
    message: 'Fixed Deposit is unavailable in this release.',
  );
  Widget _groupScreen() => _savingsUnavailableScreen(
    title: 'Group Savings',
    message: 'Group Savings is unavailable in this release.',
  );
}
