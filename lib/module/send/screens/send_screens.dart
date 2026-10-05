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
import '../../component/text_fields.dart';
import '../../core_banking/screens/boctrust_transfer_screen.dart';
import '../../core_banking/screens/interbank_transfer_screen.dart';
import '../../core_banking/screens/own_account_move_screen.dart';
import '../model/transaction_models.dart';
import '../provider/transaction_provider.dart';

part 'transaction_flow_screens.dart';

enum _SendPage {
  hub,
  ownAccount,
  beneficiary,
  otherBank,
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
    _SendPage.ownAccount =>
      _available(FeatureCapability.ownAccountTransfers) ||
              _available(FeatureCapability.savingsWithdrawals)
          ? OwnAccountMoveFlow(onExit: back, onSectionSelected: goSection)
          : _sendOwnScreen(),
    _SendPage.beneficiary =>
      _available(FeatureCapability.boctrustTransfers)
          ? BoctrustTransferFlow(onExit: back, onSectionSelected: goSection)
          : _sendBeneficiaryScreen(),
    _SendPage.otherBank =>
      _available(FeatureCapability.interbankTransfers)
          ? InterbankTransferFlow(onExit: back, onSectionSelected: goSection)
          : _available(FeatureCapability.transfers)
          ? _TransferFlow(onExit: back)
          : _sendBankScreen(),
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

/// Transfers have no server contract yet, so nothing here collects payment
/// details, resolves a recipient, or reports a result.
extension SendScreens on FlowPageState {
  Widget _sendHubScreen() {
    final transfers = [
      FeatureCapability.transfers,
      FeatureCapability.ownAccountTransfers,
      FeatureCapability.savingsWithdrawals,
      FeatureCapability.boctrustTransfers,
      FeatureCapability.interbankTransfers,
    ].any((c) => ref.watch(featureAvailabilityProvider(c)).isAvailable);
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
              AppRoutes.sendOwnAccount,
            ),
            (
              IconsaxPlusLinear.profile,
              'To a BOCTRUST account',
              'Free and instant to another BOCTRUST customer',
              AppRoutes.sendBeneficiary,
            ),
            (
              IconsaxPlusLinear.bank,
              'To another bank',
              'Send to any Nigerian bank account',
              AppRoutes.sendOtherBank,
            ),
          ]) ...[
            PaymentActionCard(
              icon: icon,
              title: title,
              subtitle: transfers ? subtitle : 'Not available yet',
              color: BocColors.goldLight,
              onTap: () => go(screen),
            ),
            const SizedBox(height: BocSpace.xs),
          ],
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
