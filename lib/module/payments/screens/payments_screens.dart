part of '../../app_flow/app_flow_navigator.dart';

/// Only wallet funding is live. Bills, airtime, data, and QR payments have no
/// server contract, so their routes explain that instead of taking input.
extension PaymentsScreens on AppFlowNavigatorState {
  Widget _paymentsScreen() {
    final colors = context.bocColors;
    return AppScaffold(
      title: 'Payments',
      activeSection: AppSection.payments,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          PaymentActionCard(
            icon: IconsaxPlusLinear.scan_barcode,
            title: 'Scan to pay',
            subtitle: 'Not available yet',
            color: colors.smartSaveContainer,
            onTap: () => _go(AppScreen.scan),
          ),
          const SizedBox(height: BocSpace.xs),
          PaymentActionCard(
            icon: IconsaxPlusLinear.card_add,
            title: 'Add money',
            subtitle: 'Top up your wallet by bank transfer',
            color: BocColors.goldLight,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.addMoney),
          ),
          const SizedBox(height: BocSpace.lg),
          Padding(
            padding: const EdgeInsets.only(bottom: BocSpace.sm),
            child: Semantics(
              header: true,
              child: Text(
                'Bill payments',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const ApiStateCard(
            title: 'Bill payments are unavailable',
            message: 'Airtime, data, and bill payments are not available yet.',
            tone: ApiStateTone.blocked,
          ),
          const SizedBox(height: BocSpace.md),
          _BillerGrid(
            billers: [
              (IconsaxPlusLinear.mobile, 'Airtime', AppScreen.airtime),
              (IconsaxPlusLinear.chart, 'Data', AppScreen.data),
              (IconsaxPlusLinear.flash, 'Electricity', AppScreen.billerList),
              (IconsaxPlusLinear.drop, 'Water', AppScreen.billerList),
              (IconsaxPlusLinear.monitor, 'Cable TV', AppScreen.billerList),
              (IconsaxPlusLinear.wifi, 'Internet', AppScreen.billerList),
              (IconsaxPlusLinear.teacher, 'Education', AppScreen.billerList),
              (IconsaxPlusLinear.more, 'More', AppScreen.billerList),
            ],
            onSelected: _go,
          ),
          const SizedBox(height: BocSpace.lg),
          const RegulatoryBadge(),
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

/// Searchable biller grid: four columns, three on narrow screens.
class _BillerGrid extends StatefulWidget {
  const _BillerGrid({required this.billers, required this.onSelected});

  final List<(IconData, String, AppScreen)> billers;
  final ValueChanged<AppScreen> onSelected;

  @override
  State<_BillerGrid> createState() => _BillerGridState();
}

class _BillerGridState extends State<_BillerGrid> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? context.bocColors.textPrimary
        : BocColors.navy2;
    final visible = [
      for (final biller in widget.billers)
        if (query.isEmpty || biller.$2.toLowerCase().contains(query)) biller,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search billers',
            prefixIcon: Icon(IconsaxPlusLinear.search_normal_1),
          ),
        ),
        const SizedBox(height: BocSpace.sm),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BocSpace.md),
            child: Text(
              'No billers match "$_query".',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 328 ? 3 : 4;
              const gap = BocSpace.xs;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final (icon, label, screen) in visible)
                    SizedBox(
                      width: width,
                      child: BillGridItem(
                        icon: icon,
                        label: label,
                        color: iconColor,
                        onTap: () => widget.onSelected(screen),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}
