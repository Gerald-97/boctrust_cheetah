import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../home/provider/home_provider.dart';
import '../model/core_account_summary.dart';
import '../model/customer_bank_account_models.dart';
import '../provider/core_account_activity_providers.dart';
import '../provider/core_account_providers.dart';
import 'core_flow_widgets.dart';

/// One Core account's live summary. Opened with the account number as the
/// route's `entityId`, or for the Flex account.
class BankAccountDetailScreen extends ConsumerStatefulWidget {
  const BankAccountDetailScreen({super.key}) : _flex = false;

  /// The customer's Core Flex account.
  const BankAccountDetailScreen.flex({super.key}) : _flex = true;

  final bool _flex;

  @override
  ConsumerState<BankAccountDetailScreen> createState() =>
      _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState
    extends FlowPageState<BankAccountDetailScreen> {
  String? get _accountNumber => widget._flex
      ? ref
            .watch(customerBankAccountsProvider)
            .data
            ?.activeFlexAccount
            ?.accountNumber
      : routeArguments.entityId;

  @override
  Widget build(BuildContext context) {
    if (!ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.coreAccountActivity),
        )
        .isAvailable) {
      return popScope(
        unavailablePage(
          const UnavailableDestination(
            title: 'Account',
            heading: 'Unavailable',
            message: 'Account details are not available yet.',
            section: AppSection.save,
            capability: FeatureCapability.coreAccountActivity,
          ),
        ),
      );
    }
    final accountNumber = _accountNumber;
    final summary = accountNumber == null
        ? null
        : ref.watch(coreAccountSummaryProvider(accountNumber));
    return popScope(
      AppScaffold(
        title: 'Account',
        activeSection: AppSection.save,
        onBack: back,
        onSectionSelected: goSection,
        body: RefreshIndicator(
          onRefresh: () => accountNumber == null
              ? Future<void>.value()
              : ref.refresh(coreAccountSummaryProvider(accountNumber).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              BocSpace.xxs,
              BocSpace.gutter,
              BocSpace.lg,
            ).clearOfNav(context),
            children: [
              switch (summary) {
                null => const ApiStateCard(
                  title: 'Account unavailable',
                  message: "This account isn't available.",
                  tone: ApiStateTone.info,
                ),
                AsyncData(:final value) when value.data != null => _summaryCard(
                  value.data!,
                ),
                AsyncData(:final value) => ApiStateCard(
                  title: 'Account unavailable',
                  message: value.statusCode == 404
                      ? "This account isn't available."
                      : value.message ?? "We couldn't load this account.",
                  tone: ApiStateTone.error,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(
                    coreAccountSummaryProvider(accountNumber!),
                  ),
                ),
                _ => const ApiLoadingSection(label: 'Loading your account'),
              },
              const SizedBox(height: BocSpace.md),
              const ApiStateCard(
                title: 'Transactions',
                message: "Transaction history isn't available yet.",
                tone: ApiStateTone.info,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(CoreAccountSummary summary) {
    final hidden = ref.watch(homeBalanceHiddenProvider);
    String money(String? value) => hidden
        ? '₦ ••••••'
        : formatApiAmount(value, currency: 'NGN') ?? 'Unavailable';
    return CoreReviewCard(
      caption: summary.product ?? 'Account',
      amount: money(summary.availableBalance),
      rows: [
        if (summary.name case final name?) (label: 'Name', value: name),
        (label: 'Account number', value: summary.accountNumber),
        if (summary.branch case final branch?) (label: 'Branch', value: branch),
        (label: 'Status', value: _status(summary.status)),
        (label: 'Ledger balance', value: money(summary.ledgerBalance)),
      ],
    );
  }

  static String _status(CoreAccountStatus status) => switch (status) {
    CoreAccountStatus.active => 'Active',
    CoreAccountStatus.frozen => 'Frozen',
    CoreAccountStatus.closed => 'Closed',
    CoreAccountStatus.unknown => 'Unavailable',
  };
}
