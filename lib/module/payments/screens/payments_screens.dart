part of '../../app_flow/app_flow_navigator.dart';

/// Only wallet funding is live. Bills, airtime, data, and QR payments have no
/// server contract, so their routes explain that instead of taking input.
extension PaymentsScreens on AppFlowNavigatorState {
  Widget _paymentsScreen() {
    return AppScaffold(
      title: 'Payments',
      activeSection: AppSection.payments,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: RegulatoryBadge(),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Send & receive'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: PaymentActionCard(
                    icon: Icons.send_rounded,
                    title: 'Send money',
                    subtitle: 'Not available yet',
                    color: BocColors.gold,
                    onTap: () => _go(AppScreen.sendHub),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PaymentActionCard(
                    icon: Icons.add_card_rounded,
                    title: 'Add money',
                    subtitle: 'Top up your wallet balance',
                    color: BocColors.blue,
                    onTap: () => _go(AppScreen.addMoney),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PaymentActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan to pay',
              subtitle: 'Not available yet',
              color: BocColors.purple,
              onTap: () => _go(AppScreen.scan),
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: 'Bill payments'),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: ApiStateCard(
              title: 'Bill payments are unavailable',
              message:
                  'Airtime, data, and bill payments are not available yet.',
              tone: ApiStateTone.blocked,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ResponsiveTiles(
              minTileWidth: 72,
              spacing: 16,
              children: [
                BillGridItem(
                  icon: Icons.phone_android_rounded,
                  label: 'Airtime',
                  color: BocColors.gold,
                  onTap: () => _go(AppScreen.airtime),
                ),
                BillGridItem(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: 'Data',
                  color: BocColors.blue,
                  onTap: () => _go(AppScreen.data),
                ),
                BillGridItem(
                  icon: Icons.bolt_outlined,
                  label: 'Electricity',
                  color: BocColors.purple,
                  onTap: () => _go(AppScreen.billerList),
                ),
                BillGridItem(
                  icon: Icons.water_drop_outlined,
                  label: 'Water',
                  color: BocColors.green,
                  onTap: () => _go(AppScreen.billerList),
                ),
                BillGridItem(
                  icon: Icons.tv_outlined,
                  label: 'Cable TV',
                  color: BocColors.gold,
                  onTap: () => _go(AppScreen.billerList),
                ),
                BillGridItem(
                  icon: Icons.wifi_rounded,
                  label: 'Internet',
                  color: BocColors.blue,
                  onTap: () => _go(AppScreen.billerList),
                ),
                BillGridItem(
                  icon: Icons.school_outlined,
                  label: 'Education',
                  color: BocColors.purple,
                  onTap: () => _go(AppScreen.billerList),
                ),
                BillGridItem(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  color: BocColors.green,
                  onTap: () => _go(AppScreen.billerList),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.scanToPay,
    title: 'Scan to pay',
    section: AppSection.payments,
    heading: 'Scan to pay is unavailable',
    message:
        'Paying with a merchant QR code or payment code is not '
        'available yet.',
  );

  Widget _airtimeScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.airtime,
    title: 'Airtime',
    section: AppSection.payments,
    heading: 'Airtime purchases are unavailable',
    message: 'Buying airtime is not available yet.',
  );

  Widget _dataScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.data,
    title: 'Data',
    section: AppSection.payments,
    heading: 'Data purchases are unavailable',
    message: 'Buying data bundles is not available yet.',
  );

  Widget _billerListScreen() => _transactionUnavailableScreen(
    capability: FeatureCapability.bills,
    title: 'Bill payments',
    section: AppSection.payments,
    heading: 'Bill payments are unavailable',
    message:
        'Paying electricity, water, TV, internet, and other bills is '
        'not available yet.',
  );

  Widget _billPayScreen() => _billerListScreen();
}
