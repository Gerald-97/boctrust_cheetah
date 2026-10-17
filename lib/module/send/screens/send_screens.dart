import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/route_arguments.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../core_banking/provider/core_account_providers.dart';
import '../../core_banking/screens/core_account_history_list.dart';
import '../../core_banking/screens/core_flow_widgets.dart';
import '../../core_banking/screens/interbank_transfer_screen.dart';
import '../../core_banking/screens/snap_to_pay_page.dart';
import '../model/transaction_models.dart';
import '../provider/transaction_provider.dart';

part 'transaction_flow_screens.dart';

enum _SendPage {
  hub,
  ownAccount,
  beneficiary,
  otherBank,
  scan,
  authorize,
  receipt,
  detail,
  history,
}

/// Send money, transaction history, detail, authorization and receipts.
class SendScreen extends ConsumerStatefulWidget {
  const SendScreen.hub({super.key}) : _page = _SendPage.hub;
  const SendScreen.ownAccount({super.key}) : _page = _SendPage.ownAccount;
  const SendScreen.beneficiary({super.key}) : _page = _SendPage.beneficiary;
  const SendScreen.otherBank({super.key}) : _page = _SendPage.otherBank;
  const SendScreen.scan({super.key}) : _page = _SendPage.scan;
  const SendScreen.authorize({super.key}) : _page = _SendPage.authorize;
  const SendScreen.receipt({super.key}) : _page = _SendPage.receipt;
  const SendScreen.detail({super.key}) : _page = _SendPage.detail;
  const SendScreen.history({super.key}) : _page = _SendPage.history;

  final _SendPage _page;

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends FlowPageState<SendScreen> {
  bool _available(FeatureCapability capability) =>
      ref.watch(featureAvailabilityProvider(capability)).isAvailable;

  @override
  Widget build(BuildContext context) => popScope(switch (widget._page) {
    _SendPage.hub => _sendHubScreen(),
    _SendPage.ownAccount => _sendOwnScreen(),
    _SendPage.beneficiary =>
      _available(FeatureCapability.boctrustTransfers)
          ? InterbankTransferFlow.boctrust(
              onExit: back,
              onSectionSelected: goSection,
              initialAccountNumber: routeArguments.entityId,
            )
          : _sendBeneficiaryScreen(),
    _SendPage.otherBank =>
      _available(FeatureCapability.interbankTransfers)
          ? InterbankTransferFlow(
              onExit: back,
              onSectionSelected: goSection,
              initialAccountNumber: routeArguments.entityId,
              initialBankCode: routeArguments.bankCode,
            )
          : _sendBankScreen(),
    _SendPage.scan => _scanScreen(),
    _SendPage.authorize => _authPinScreen(),
    _SendPage.receipt => _successScreen(),
    _SendPage.detail => _transactionDetailScreen(),
    _SendPage.history =>
      _available(FeatureCapability.transactionHistory)
          ? _transactionHistoryScreen()
          : unavailablePage(_historyUnavailable),
  });
}

const _historyUnavailable = UnavailableDestination(
  title: 'Transactions',
  heading: 'Transaction history is unavailable',
  message: 'Your transaction history cannot be displayed yet.',
  section: AppSection.payments,
  capability: FeatureCapability.transactionHistory,
);

/// Transfer destinations and their unavailable fallbacks.
extension SendScreens on FlowPageState {
  Widget _sendHubScreen() {
    final boctrustAvailable = ref
        .watch(featureAvailabilityProvider(FeatureCapability.boctrustTransfers))
        .isAvailable;
    final interbankAvailable = ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.interbankTransfers),
        )
        .isAvailable;
    final scanAvailable = ref
        .watch(featureAvailabilityProvider(FeatureCapability.scanToPay))
        .isAvailable;
    return AppScaffold(
      title: 'Send money',
      activeSection: AppSection.send,
      onSectionSelected: goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          BocSpace.gutter,
          BocSpace.xxs,
          BocSpace.gutter,
          BocSpace.lg,
        ).clearOfNav(context),
        children: [
          if (!boctrustAvailable && !interbankAvailable && !scanAvailable) ...[
            const ApiStateCard(
              title: 'Sending money is unavailable',
              message: 'These payment options are not available right now.',
              tone: ApiStateTone.blocked,
            ),
            const SizedBox(height: BocSpace.lg),
          ],
          SettingsGroup(
            caption: 'Bank transfers',
            padding: EdgeInsets.zero,
            children: [
              SettingsTile(
                icon: IconsaxPlusLinear.profile,
                title: 'To a BOCTRUST account',
                subtitle: boctrustAvailable
                    ? 'Send instantly to another BOCTRUST customer'
                    : 'Not available yet',
                onTap: () {
                  if (!transfersPaused(context, ref)) {
                    go(AppRoutes.sendBeneficiary);
                  }
                },
              ),
              SettingsTile(
                icon: IconsaxPlusLinear.bank,
                title: 'To another bank',
                subtitle: interbankAvailable
                    ? 'Send to any Nigerian bank account'
                    : 'Not available yet',
                onTap: () {
                  if (!transfersPaused(context, ref)) {
                    go(AppRoutes.sendOtherBank);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: BocSpace.lg),
          SettingsGroup(
            caption: 'Pay with a photo',
            padding: EdgeInsets.zero,
            children: [
              SettingsTile(
                icon: IconsaxPlusLinear.scan_barcode,
                title: 'Scan to pay',
                subtitle: scanAvailable
                    ? 'Read an account number from a photo'
                    : 'Not available yet',
                onTap: _openScanToPay,
              ),
            ],
          ),
          const SizedBox(height: BocSpace.lg),
          const RegulatoryBadge(),
        ],
      ),
    );
  }

  Widget _sendOwnScreen() => transactionUnavailablePage(
    capability: FeatureCapability.transfers,
    title: 'Move between savings',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Moving money between your savings is not available yet.',
  );

  Widget _sendBeneficiaryScreen() => transactionUnavailablePage(
    capability: FeatureCapability.transfers,
    title: 'Send to beneficiary',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Sending money to another BOCTRUST user is not available yet.',
  );

  Widget _sendBankScreen() => transactionUnavailablePage(
    capability: FeatureCapability.transfers,
    title: 'Send to other bank',
    section: AppSection.send,
    heading: 'Transfers are unavailable',
    message: 'Sending money to another bank is not available yet.',
  );

  /// Camera access is settled before the page opens, so the system prompt
  /// never covers the viewfinder.
  Future<void> _openScanToPay() async {
    if (transfersPaused(context, ref)) return;
    if (ref
        .read(featureAvailabilityProvider(FeatureCapability.scanToPay))
        .isAvailable) {
      await prepareScanCamera();
    }
    if (mounted) go(AppRoutes.scanToPay);
  }

  Widget _scanScreen() =>
      ref
          .watch(featureAvailabilityProvider(FeatureCapability.scanToPay))
          .isAvailable
      ? SnapToPayPage(
          onExit: back,
          onSend: (route, number, bankCode) => go(
            route,
            arguments: AppRouteArguments(entityId: number, bankCode: bankCode),
          ),
        )
      : _scanUnavailable();

  Widget _scanUnavailable() => transactionUnavailablePage(
    capability: FeatureCapability.scanToPay,
    title: 'Scan to pay',
    section: AppSection.send,
    heading: 'Scan to pay is unavailable',
    message: 'Reading an account from a photo is not available right now.',
  );

  /// Checking a PIN is not a transaction contract: without a server-bound
  /// authorization there is nothing to confirm, so no PIN is collected.
  Widget _authPinScreen() => transactionUnavailablePage(
    capability: FeatureCapability.transfers,
    title: 'Authorize transaction',
    section: AppSection.send,
    heading: 'Transaction authorization is unavailable',
    message: 'Transfers and bill payments are not available yet.',
  );

  /// Receipts may only ever render confirmed server data. None exists, so a
  /// direct or notification entry — with or without an id — shows this.
  Widget _successScreen() => transactionUnavailablePage(
    capability: FeatureCapability.transactionReceipts,
    title: 'Receipt',
    section: AppSection.send,
    heading: 'Transaction receipts are unavailable',
    message:
        'Receipts cannot be displayed because transactions are not '
        'available yet.',
  );

  Widget transactionUnavailablePage({
    required FeatureCapability capability,
    required String title,
    required AppSection section,
    required String heading,
    required String message,
  }) => unavailablePage(
    UnavailableDestination(
      title: title,
      heading: heading,
      message: message,
      section: section,
      capability: capability,
    ),
  );
}
