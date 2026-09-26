part of '../../app_flow/app_flow_navigator.dart';

/// Transfers have no server contract yet, so nothing here collects payment
/// details, resolves a recipient, or reports a result.
extension SendScreens on AppFlowNavigatorState {
  Widget _sendHubScreen() {
    return AppScaffold(
      title: 'Send money',
      activeSection: AppSection.send,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const ApiStateCard(
            title: 'Transfers are unavailable',
            message: 'Sending money is not available in this release.',
            tone: ApiStateTone.blocked,
          ),
          const SizedBox(height: 18),
          ProductTile(
            icon: Icons.swap_horiz_rounded,
            title: 'To my own account',
            subtitle: 'Not available yet',
            color: BocColors.gold,
            onTap: () => _go(AppScreen.sendOwn),
          ),
          ProductTile(
            icon: Icons.person_outline_rounded,
            title: 'To a Cheetah beneficiary',
            subtitle: 'Not available yet',
            color: BocColors.blue,
            onTap: () => _go(AppScreen.sendBeneficiary),
          ),
          ProductTile(
            icon: Icons.account_balance_outlined,
            title: 'To another bank',
            subtitle: 'Not available yet',
            color: BocColors.purple,
            onTap: () => _go(AppScreen.sendBank),
          ),
        ],
      ),
    );
  }

  Widget _sendOwnScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.transfers,
    title: 'Move between savings',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Moving money between your savings is not available yet.',
  );

  Widget _sendBeneficiaryScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.transfers,
    title: 'Send to beneficiary',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Sending money to another Cheetah user is not available yet.',
  );

  Widget _sendBankScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.transfers,
    title: 'Send to other bank',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Sending money to another bank is not available yet.',
  );

  /// Checking a PIN is not a transaction contract: without a server-bound
  /// authorization there is nothing to confirm, so no PIN is collected.
  Widget _authPinScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.transfers,
    title: 'Authorize transaction',
    section: AppSection.send,
    heading: 'Transaction authorization is unavailable',
    message: 'Transfers and bill payments are not available yet.',
  );

  /// Receipts may only ever render confirmed server data. None exists, so a
  /// direct or notification entry — with or without an id — shows this.
  Widget _successScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.transactionReceipts,
    title: 'Receipt',
    section: AppSection.send,
    heading: 'Transaction receipts are unavailable',
    message:
        'Receipts cannot be displayed because transactions are not '
        'available yet.',
  );

  Widget _transactionUnavailableScreen({
    required FeatureCapability capability,
    required String title,
    required AppSection section,
    required String heading,
    required String message,
  }) {
    _assertPlaceholderFor(capability, FeatureAvailability.unavailable);
    return AppScaffold(
      title: title,
      activeSection: section,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ApiStateCard(
            title: heading,
            message: message,
            tone: ApiStateTone.blocked,
          ),
        ],
      ),
    );
  }

  /// A placeholder screen may only stand in for a capability the registry
  /// still reports in [expected]; switching one on without building its real
  /// screen fails fast in debug builds.
  void _assertPlaceholderFor(
    FeatureCapability capability,
    FeatureAvailability expected,
  ) {
    assert(
      ref.read(featureAvailabilityProvider(capability)) == expected,
      '$capability is no longer $expected but still shows a placeholder.',
    );
  }
}
