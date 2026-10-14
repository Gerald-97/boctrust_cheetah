import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../home/provider/home_provider.dart';
import '../model/core_account_summary.dart';
import '../model/core_account_transactions.dart' show CoreHistoryRange;
import '../model/customer_bank_account_models.dart';
import '../provider/core_account_activity_providers.dart';
import '../provider/core_account_providers.dart';
import 'core_account_history_list.dart';

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
  CoreHistoryRange _range = CoreHistoryRange.last30Days;

  @override
  void initState() {
    super.initState();
    // The Flex account's number comes from the account list.
    if (widget._flex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(customerBankAccountsProvider.notifier).ensureLoaded();
        }
      });
    }
  }

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
    final historyAvailable = ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.coreAccountHistory),
        )
        .isAvailable;
    return popScope(
      AppScaffold(
        title: 'Account',
        activeSection: AppSection.save,
        onBack: back,
        onSectionSelected: goSection,
        body: RefreshIndicator(
          onRefresh: () => accountNumber == null
              ? Future<void>.value()
              : Future.wait([
                  ref.refresh(coreAccountSummaryProvider(accountNumber).future),
                  if (historyAvailable)
                    ref
                        .read(
                          coreAccountHistoryProvider((
                            accountNumber: accountNumber,
                            range: _range,
                          )).notifier,
                        )
                        .reload(),
                ]),
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
              const SizedBox(height: BocSpace.sectionGap),
              if (historyAvailable && accountNumber != null)
                CoreAccountHistoryList(
                  key: ValueKey(accountNumber),
                  accountNumber: accountNumber,
                  onRangeChanged: (range) => _range = range,
                )
              else
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
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final ledgerBalance = formatApiAmount(
      summary.ledgerBalance,
      currency: 'NGN',
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(BocSpace.md),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(BocRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.infoContainer,
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
                child: Icon(
                  IconsaxPlusLinear.bank,
                  color: colors.info,
                  size: 21,
                ),
              ),
              const SizedBox(width: BocSpace.sm),
              Expanded(
                child: Text(
                  'Account ${summary.accountNumber}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _statusBadge(summary.status),
            ],
          ),
          const SizedBox(height: BocSpace.md),
          Divider(color: colors.border, height: 1),
          const SizedBox(height: BocSpace.md),
          Text(
            'Ledger balance',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: BocSpace.xxs),
          BocMoneyText(
            ledgerBalance ?? 'Unavailable',
            hidden: hidden && ledgerBalance != null,
            semanticsLabel: 'Ledger balance',
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(CoreAccountStatus status) {
    final colors = context.bocColors;
    final active = status == CoreAccountStatus.active;
    final foreground = active ? colors.successText : colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: BocSpace.sm,
        vertical: BocSpace.xs,
      ),
      decoration: BoxDecoration(
        color: active ? colors.successContainer : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(BocRadius.pill),
      ),
      child: Text(
        _status(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _status(CoreAccountStatus status) => switch (status) {
    CoreAccountStatus.active => 'Active',
    CoreAccountStatus.frozen => 'Frozen',
    CoreAccountStatus.closed => 'Closed',
    CoreAccountStatus.unknown => 'Unavailable',
  };
}
