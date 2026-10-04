part of '../../app_flow/app_flow_navigator.dart';

/// Transfers have no server contract yet, so nothing here collects payment
/// details, resolves a recipient, or reports a result.
extension SendScreens on AppFlowNavigatorState {
  Widget _sendHubScreen() {
    final transfers = ref
        .watch(featureAvailabilityProvider(FeatureCapability.transfers))
        .isAvailable;
    return AppScaffold(
      title: 'Send money',
      activeSection: AppSection.send,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          if (!transfers) ...[
            const ApiStateCard(
              title: 'Transfers are unavailable',
              message: 'Sending money is not available in this release.',
              tone: ApiStateTone.blocked,
            ),
            const SizedBox(height: BocSpace.md),
          ],
          for (final (icon, title, subtitle, screen) in const [
            (
              IconsaxPlusLinear.arrow_swap_horizontal,
              'Between my accounts',
              'Between your Flex, SmartSave, Fixed and Padi plans',
              AppScreen.sendOwn,
            ),
            (
              IconsaxPlusLinear.profile,
              'To a BOCTRUST account',
              'Free and instant to another BOCTRUST customer',
              AppScreen.sendBeneficiary,
            ),
            (
              IconsaxPlusLinear.bank,
              'To another bank',
              'Send to any Nigerian bank account',
              AppScreen.sendBank,
            ),
          ]) ...[
            PaymentActionCard(
              icon: icon,
              title: title,
              subtitle: transfers ? subtitle : 'Not available yet',
              color: BocColors.goldLight,
              onTap: () => _go(screen),
            ),
            const SizedBox(height: BocSpace.xs),
          ],
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
    message: 'Sending money to another BOCTRUST user is not available yet.',
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
  }) => _unavailableScreen(
    UnavailableDestination(
      title: title,
      heading: heading,
      message: message,
      section: section,
      capability: capability,
    ),
  );

  /// Savings pages keep a way back to the Savings hub.
  Widget _unavailableScreen(UnavailableDestination destination) {
    final capability = destination.capability;
    if (capability != null) {
      _assertPlaceholderFor(capability, FeatureAvailability.unavailable);
    }
    return UnavailableFeatureScreen(
      destination: destination,
      onBack: _back,
      onSectionSelected: _goSection,
      action: destination.section == AppSection.save
          ? OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.savingsHub),
              child: const Text('Back to Savings'),
            )
          : null,
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
