import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../core_banking/model/bill_models.dart';
import '../../core_banking/screens/bill_payment_screen.dart';
import '../../send/screens/send_screens.dart';

enum _PaymentsPage { hub, bills }

/// The Payments hub and its bill, airtime, data and QR destinations.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen.hub({super.key})
    : _page = _PaymentsPage.hub,
      _group = null,
      _searchFirst = false;
  const PaymentsScreen.airtime({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.airtime,
      _searchFirst = false;
  const PaymentsScreen.data({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.data,
      _searchFirst = false;
  const PaymentsScreen.electricity({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.electricity,
      _searchFirst = false;
  const PaymentsScreen.water({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.water,
      _searchFirst = false;
  const PaymentsScreen.cableTv({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.cableTv,
      _searchFirst = false;
  const PaymentsScreen.internet({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.internet,
      _searchFirst = false;
  const PaymentsScreen.education({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.education,
      _searchFirst = false;

  /// More: every category, chosen by the customer.
  const PaymentsScreen.billers({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.all,
      _searchFirst = false;

  /// More, opened from the hub's search with its search field focused.
  const PaymentsScreen.search({super.key})
    : _page = _PaymentsPage.bills,
      _group = BillerGroup.all,
      _searchFirst = true;

  final _PaymentsPage _page;

  /// The bill tile this page opens; null for the hub.
  final BillerGroup? _group;

  final bool _searchFirst;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends FlowPageState<PaymentsScreen> {
  bool _available(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  @override
  Widget build(BuildContext context) => popScope(switch (widget._page) {
    _PaymentsPage.hub => _paymentsScreen(),
    _PaymentsPage.bills => _billsPage(widget._group ?? BillerGroup.all),
  });

  Widget _billsPage(BillerGroup group) {
    final capability = switch (group) {
      BillerGroup.airtime => FeatureCapability.airtime,
      BillerGroup.data => FeatureCapability.data,
      _ => FeatureCapability.bills,
    };
    if (_available(capability)) {
      return BillPaymentFlow(
        group: group,
        searchFirst: widget._searchFirst,
        onExit: back,
        onSectionSelected: goSection,
      );
    }
    return switch (group) {
      BillerGroup.airtime => _airtimeScreen(),
      BillerGroup.data => _dataScreen(),
      _ => _billerListScreen(),
    };
  }
}

/// Bill payments use Core where available; unavailable routes stay explicit.
extension PaymentsScreens on FlowPageState {
  Widget _paymentsScreen() {
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
          if (!ref
              .watch(featureAvailabilityProvider(FeatureCapability.bills))
              .isAvailable) ...[
            const ApiStateCard(
              title: 'Bill payments are unavailable',
              message:
                  'Airtime, data, and bill payments are not available yet.',
              tone: ApiStateTone.blocked,
            ),
            const SizedBox(height: BocSpace.md),
          ],
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
            onSearch: () => go(AppRoutes.billerSearch),
          ),
          const SizedBox(height: BocSpace.lg),
          const RegulatoryBadge(),
        ],
      ),
    );
  }

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

/// Biller grid: four columns, three on narrow screens. Its search field
/// opens More, where every biller can be searched.
class _BillerGrid extends StatelessWidget {
  const _BillerGrid({
    required this.billers,
    required this.onSelected,
    required this.onSearch,
  });

  final List<(IconData, String, String)> billers;
  final ValueChanged<String> onSelected;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).brightness == Brightness.dark
        ? context.bocColors.textPrimary
        : BocColors.navy2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          readOnly: true,
          onTap: onSearch,
          decoration: const InputDecoration(
            hintText: 'Search billers',
            prefixIcon: Icon(IconsaxPlusLinear.search_normal_1),
          ),
        ),
        const SizedBox(height: BocSpace.sm),
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
                for (final (icon, label, screen) in billers)
                  SizedBox(
                    width: width,
                    child: BillGridItem(
                      icon: icon,
                      label: label,
                      color: iconColor,
                      onTap: () => onSelected(screen),
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
