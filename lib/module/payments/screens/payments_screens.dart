import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../send/screens/send_screens.dart';

enum _PaymentsPage { hub, scan, airtime, data, billers }

/// The Payments hub and its bill, airtime, data and QR destinations.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen.hub({super.key}) : _page = _PaymentsPage.hub;
  const PaymentsScreen.scan({super.key}) : _page = _PaymentsPage.scan;
  const PaymentsScreen.airtime({super.key}) : _page = _PaymentsPage.airtime;
  const PaymentsScreen.data({super.key}) : _page = _PaymentsPage.data;

  /// Every biller category and bill pay share one unavailable page.
  const PaymentsScreen.billers({super.key}) : _page = _PaymentsPage.billers;

  final _PaymentsPage _page;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends FlowPageState<PaymentsScreen> {
  @override
  void onNothingToPop() {
    if (widget._page == _PaymentsPage.hub) goReplacing(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) => popScope(switch (widget._page) {
    _PaymentsPage.hub => _paymentsScreen(),
    _PaymentsPage.scan => _scanScreen(),
    _PaymentsPage.airtime => _airtimeScreen(),
    _PaymentsPage.data => _dataScreen(),
    _PaymentsPage.billers => _billerListScreen(),
  });
}

/// Only wallet funding is live. Bills, airtime, data, and QR payments have no
/// server contract, so their routes explain that instead of taking input.
extension PaymentsScreens on FlowPageState {
  Widget _paymentsScreen() {
    final colors = context.bocColors;
    return AppScaffold(
      title: 'Payments',
      activeSection: AppSection.payments,
      onSectionSelected: goSection,
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
            onTap: () => go(AppRoutes.scanToPay),
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
              (IconsaxPlusLinear.mobile, 'Airtime', AppRoutes.airtime),
              (IconsaxPlusLinear.chart, 'Data', AppRoutes.data),
              (
                IconsaxPlusLinear.flash,
                'Electricity',
                AppRoutes.billerListElectricity,
              ),
              (IconsaxPlusLinear.drop, 'Water', AppRoutes.billerListWater),
              (
                IconsaxPlusLinear.monitor,
                'Cable TV',
                AppRoutes.billerListCable,
              ),
              (
                IconsaxPlusLinear.wifi,
                'Internet',
                AppRoutes.billerListInternet,
              ),
              (
                IconsaxPlusLinear.teacher,
                'Education',
                AppRoutes.billerListEducation,
              ),
              (IconsaxPlusLinear.more, 'More', AppRoutes.billerListMore),
            ],
            onSelected: go,
          ),
          const SizedBox(height: BocSpace.lg),
          const RegulatoryBadge(),
        ],
      ),
    );
  }

  Widget _scanScreen() => transactionUnavailablePage(
    capability: FeatureCapability.scanToPay,
    title: 'Scan to pay',
    section: AppSection.payments,
    heading: 'Scan to pay is unavailable',
    message:
        'Paying with a merchant QR code or payment code is not '
        'available yet.',
  );

  Widget _airtimeScreen() => transactionUnavailablePage(
    capability: FeatureCapability.airtime,
    title: 'Airtime',
    section: AppSection.payments,
    heading: 'Airtime purchases are unavailable',
    message: 'Buying airtime is not available yet.',
  );

  Widget _dataScreen() => transactionUnavailablePage(
    capability: FeatureCapability.data,
    title: 'Data',
    section: AppSection.payments,
    heading: 'Data purchases are unavailable',
    message: 'Buying data bundles is not available yet.',
  );

  Widget _billerListScreen() => transactionUnavailablePage(
    capability: FeatureCapability.bills,
    title: 'Bill payments',
    section: AppSection.payments,
    heading: 'Bill payments are unavailable',
    message:
        'Paying electricity, water, TV, internet, and other bills is '
        'not available yet.',
  );
}

/// Searchable biller grid: four columns, three on narrow screens.
class _BillerGrid extends StatefulWidget {
  const _BillerGrid({required this.billers, required this.onSelected});

  final List<(IconData, String, String)> billers;
  final ValueChanged<String> onSelected;

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
