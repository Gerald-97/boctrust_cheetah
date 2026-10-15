import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../app/api_logger.dart';
import '../../../app/app_router.dart';
import '../../../app/boc_icons.dart';
import '../../../app/feature_capability.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../account/provider/user_providers.dart';
import '../../account/screens/contact_verification.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../core_banking/model/customer_bank_account_models.dart';
import '../../core_banking/model/core_account_transactions.dart';
import '../../core_banking/model/flex_balance.dart';
import '../../core_banking/provider/core_account_activity_providers.dart';
import '../../core_banking/provider/core_account_providers.dart';
import '../../core_banking/screens/core_transaction_detail_sheet.dart';
import '../../kyc/model/kyc_contact_requirement.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/user_home_model.dart';
import '../provider/home_provider.dart';

/// The signed-in landing page.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends FlowPageState<HomeScreen> {
  @override
  Widget build(BuildContext context) => popScope(_homeScreen());
}

extension HomeScreenParts on FlowPageState {
  Widget _homeScreen() {
    final profileState = ref.watch(userProfileProvider);
    final tierState = ref.watch(userTierProvider);
    final homeState = ref.watch(userHomeProvider);
    final accountsState = ref.watch(customerBankAccountsProvider);
    final session = ref.watch(authSessionProvider);
    final profile = profileState.data;
    final tier = tierState.data;

    if (profileState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    if (tierState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userTierProvider.notifier).load);
    }
    if (homeState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userHomeProvider.notifier).load);
    }
    if (accountsState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(
        ref.read(customerBankAccountsProvider.notifier).load,
      );
    }

    final displayName = profile?.firstName?.trim().isNotEmpty == true
        ? profile!.firstName!.trim()
        : 'there';
    final identifier =
        profile?.phoneNumber ??
        profile?.email ??
        session?.phoneNumber ??
        session?.email;
    final tierSummary = tier?.currentTierSummary;
    final topTier = tier?.tiers.fold<int>(
      0,
      (highest, card) => card.tier > highest ? card.tier : highest,
    );
    final contactsReadyForKyc = areContactsReadyForKyc(profile);
    final hasHigherTier =
        tier != null && topTier != null && tier.currentTier < topTier;
    // Fully verified customers have no KYC left, so no contact prompt.
    final kycRemaining = tier == null || hasHigherTier;
    final canUpgrade = hasHigherTier && contactsReadyForKyc;
    final colors = context.bocColors;
    final theme = Theme.of(context);

    return AppScaffold(
      titleWidget: const CheetahBrand.header(),
      activeSection: AppSection.home,
      onSectionSelected: goSection,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.notifications),
          icon: const Icon(IconsaxPlusLinear.notification),
        ),
        const SizedBox(width: BocSpace.xs),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
            ref.read(userHomeProvider.notifier).load(),
            ref.read(customerBankAccountsProvider.notifier).load(),
          ]);
          if (!mounted) return;
          final accountNumber = ref
              .read(customerBankAccountsProvider)
              .data
              ?.activeFlexAccount
              ?.accountNumber;
          if (accountNumber != null &&
              ref
                  .read(
                    featureAvailabilityProvider(
                      FeatureCapability.coreAccountHistory,
                    ),
                  )
                  .isAvailable) {
            await ref
                .read(
                  coreAccountHistoryProvider((
                    accountNumber: accountNumber,
                    range: CoreHistoryRange.last30Days,
                  )).notifier,
                )
                .reload();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xs,
            BocSpace.gutter,
            BocSpace.lg,
          ).clearOfNav(context),
          children: [
            Semantics(
              header: true,
              child: Text(
                'Hi, $displayName',
                style: theme.textTheme.titleLarge,
              ),
            ),
            if (identifier != null) ...[
              const SizedBox(height: BocSpace.xxs),
              Text(identifier, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: BocSpace.md),
            if (profileState.isError || tierState.isError) ...[
              ApiStateCard(
                title: 'Some account details did not load',
                message:
                    profileState.message ??
                    tierState.message ??
                    'Unable to refresh your account details.',
                tone: ApiStateTone.warning,
                actionLabel: 'Retry',
                onAction: () async {
                  await Future.wait([
                    ref.read(userProfileProvider.notifier).load(),
                    ref.read(userTierProvider.notifier).load(),
                  ]);
                },
              ),
              const SizedBox(height: BocSpace.md),
            ],
            ..._homeWalletSection(accountsState, homeState),
            if (profile != null && !contactsReadyForKyc && kycRemaining) ...[
              const SizedBox(height: BocSpace.sm),
              contactRequirementCard(
                profile,
                onVerified: () =>
                    Navigator.of(context).pushNamed(AppRoutes.tierOverview),
              ),
            ],
            const SizedBox(height: BocSpace.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: BocSpace.xs,
                vertical: BocSpace.sm,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(BocRadius.md),
              ),
              child: Row(
                children: [
                  for (final (icon, label, screen) in const [
                    (IconsaxPlusLinear.add, 'Add money', AppRoutes.addMoney),
                    (IconsaxPlusLinear.send_2, 'Send', AppRoutes.sendHub),
                    (BocIcons.savings, 'Save', AppRoutes.savingsHub),
                    (
                      IconsaxPlusLinear.receipt_item,
                      'Pay',
                      AppRoutes.paymentsHub,
                    ),
                  ])
                    Expanded(
                      child: QuickAction(
                        icon: icon,
                        label: label,
                        background: colors.smartSaveContainer,
                        foreground: theme.brightness == Brightness.dark
                            ? colors.textPrimary
                            : BocColors.navy,
                        onTap: () => go(screen),
                      ),
                    ),
                ],
              ),
            ),
            if (canUpgrade && tierSummary != null) ...[
              const SizedBox(height: BocSpace.sm),
              Container(
                padding: const EdgeInsets.all(BocSpace.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(BocRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.smartSaveContainer,
                            borderRadius: BorderRadius.circular(BocRadius.sm),
                          ),
                          child: SizedBox.square(
                            dimension: 40,
                            child: Icon(
                              IconsaxPlusLinear.shield_tick,
                              color: colors.smartSaveAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: BocSpace.sm),
                        Expanded(
                          child: Text(
                            tierSummary.tierLabel,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: BocSpace.sm),
                    _HomeLimitLine(
                      label: 'Daily transfer limit',
                      value: tierSummary.dailyTransferLimit.displayValue,
                    ),
                    _HomeLimitLine(
                      label: 'Max wallet balance',
                      value: tierSummary.maxWalletBalance.displayValue,
                    ),
                    const SizedBox(height: BocSpace.sm),
                    SecondaryButton(
                      label: 'Complete KYC',
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(AppRoutes.tierOverview),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: BocSpace.xs),
            _homeTransactionsSection(
              accountsState.data?.activeFlexAccount?.accountNumber,
            ),
          ],
        ),
      ),
    );
  }

  /// Wallet hero: the Flex balance beside the User Service funding account.
  ///
  /// Core's Flex account is authoritative once the customer has one; until
  /// then the User Service Flex wallet is shown (see `resolveFlexBalance`).
  List<Widget> _homeWalletSection(
    NotifierState<CustomerBankAccountsData> accountsState,
    NotifierState<UserHomeData> homeState,
  ) {
    final flex = resolveFlexBalance(
      core: accountsState.data,
      wallet: homeState.data?.flexWallet,
    );
    Future<void> retry() => Future.wait([
      ref.read(customerBankAccountsProvider.notifier).load(),
      ref.read(userHomeProvider.notifier).load(),
    ]);
    bool pending(NotifierState<Object?> state) =>
        state.data == null &&
        (state.isLoading || state.status == ServiceStatus.idle);

    if (flex == null) {
      if (pending(accountsState) || pending(homeState)) {
        return [const _HomeWalletSkeleton()];
      }
      final bothFailed = accountsState.data == null && homeState.data == null;
      return [
        bothFailed
            ? ApiStateCard(
                title: 'Balance unavailable',
                message: 'We could not load your wallet balance.',
                tone: ApiStateTone.error,
                actionLabel: 'Retry',
                onAction: retry,
              )
            : const ApiStateCard(
                title: 'Wallet information unavailable',
                message:
                    'Your wallet details are unavailable right now. Refresh '
                    'to try again.',
                tone: ApiStateTone.info,
              ),
      ];
    }

    final source = flex.isCoreAccount ? accountsState : homeState;
    return [
      if (source.isError) ...[
        ApiStateCard(
          title: 'Showing your last known balance',
          message: source.message ?? 'We could not refresh your wallet.',
          tone: ApiStateTone.warning,
          actionLabel: 'Retry',
          onAction: retry,
        ),
        const SizedBox(height: 14),
      ],
      _flexWalletCard(flex, loading: source.isLoading),
    ];
  }

  Widget _flexWalletCard(FlexBalance flex, {required bool loading}) {
    final hidden = ref.watch(homeBalanceHiddenProvider);
    final available = formatApiAmount(flex.availableBalance, currency: 'NGN');
    // The customer's funding account number and bank, shown whenever the
    // User Service returns them.
    final funding = ref.watch(userHomeProvider).data?.dedicatedVirtualAccount;
    String? present(String? value) {
      final text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final accountNumber = present(funding?.accountNumber);
    final bankName = accountNumber == null ? null : present(funding?.bankName);
    final accountName = accountNumber == null
        ? null
        : present(funding?.accountName);

    return BalanceCard(
      label: 'Wallet balance',
      balance: available,
      hidden: hidden,
      onToggle: () => ref.read(homeBalanceHiddenProvider.notifier).toggle(),
      accountNumber: accountNumber,
      accountName: accountName,
      bankName: bankName,
      onCopyAccountNumber: accountNumber == null || funding == null
          ? null
          : () => _copyFundingAccountNumber(funding),
      tier: ref.watch(userTierProvider).data?.currentTier,
      loading: loading,
    );
  }

  Widget _homeTransactionsSection(String? accountNumber) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final available = ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.coreAccountHistory),
        )
        .isAvailable;
    final key = accountNumber == null
        ? null
        : (accountNumber: accountNumber, range: CoreHistoryRange.last30Days);
    final state = available && key != null
        ? ref.watch(coreAccountHistoryProvider(key))
        : null;
    final history = state?.data;
    final canSeeAll =
        history?.rows.isNotEmpty == true &&
        ref
            .watch(
              featureAvailabilityProvider(
                FeatureCapability.coreAccountActivity,
              ),
            )
            .isAvailable;
    final hidden = ref.watch(homeBalanceHiddenProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Recent transactions',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            if (canSeeAll)
              TextButton(
                onPressed: () => go(AppRoutes.flexStatement),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: BocSpace.xs),
        if (!available)
          const ApiStateCard(
            title: 'Transactions unavailable',
            message: 'Transaction history is not available right now.',
            tone: ApiStateTone.info,
          )
        else if (accountNumber == null)
          ref.watch(customerBankAccountsProvider).isLoading
              ? const _HomeTransactionsSkeleton()
              : _HomeTransactionsEmpty(
                  message:
                      'Your transactions will appear when your Flex account is ready.',
                )
        else if (history == null && state!.isError)
          ApiStateCard(
            title: 'Transactions unavailable',
            message: state.message ?? "We couldn't load your transactions.",
            tone: ApiStateTone.warning,
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(coreAccountHistoryProvider(key!)),
          )
        else if (history == null)
          const _HomeTransactionsSkeleton()
        else ...[
          if (history.failure != null) ...[
            ApiStateCard(
              title: 'Refresh failed',
              message: history.failure!,
              tone: ApiStateTone.warning,
              actionLabel: 'Retry',
              onAction: () =>
                  ref.read(coreAccountHistoryProvider(key!).notifier).reload(),
            ),
            const SizedBox(height: BocSpace.sm),
          ],
          if (history.rows.isEmpty && history.failure == null)
            const _HomeTransactionsEmpty(
              message:
                  'Your Flex transactions from the last 30 days will appear here.',
            )
          else if (history.rows.isNotEmpty)
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (index, row) in history.rows.take(4).indexed) ...[
                    if (index > 0)
                      Divider(
                        height: 1,
                        indent: BocSpace.md,
                        endIndent: BocSpace.md,
                        color: colors.border,
                      ),
                    _HomeTransactionRow(row: row, hidden: hidden),
                  ],
                ],
              ),
            ),
        ],
      ],
    );
  }

  /// Copies the funding account number only while the session and the Home
  /// data it came from are still current.
  Future<void> _copyFundingAccountNumber(
    DedicatedVirtualAccountData account,
  ) async {
    final current = ref.read(userHomeProvider);
    final session = ref.read(authSessionProvider);
    final number = account.accountNumber?.trim();
    if (number == null ||
        session == null ||
        session.isExpired ||
        !current.isDone ||
        current.data?.dedicatedVirtualAccount != account) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: number));
    if (mounted && ref.read(authSessionProvider) == session) {
      showSuccessMessage('Account number copied.');
    }
  }

  /// Whatever account details the User Service returned, as lines appended
  /// to a funding status card; empty when it returned none.
  String _virtualAccountDetails(DedicatedVirtualAccountData account) {
    String? present(String? value) {
      final text = value?.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final lines = [
      if (present(account.accountNumber) case final number?)
        'Account number: $number',
      if (present(account.bankName) case final bank?) 'Bank: $bank',
      if (present(account.accountName) case final name?) 'Account name: $name',
    ];
    return lines.isEmpty ? '' : '\n\n${lines.join('\n')}';
  }

  Widget dedicatedVirtualAccountCard(DedicatedVirtualAccountData? account) {
    Future<void> refresh() => ref.read(userHomeProvider.notifier).load();

    if (account == null) {
      return const ApiStateCard(
        title: 'Funding information unavailable',
        message: 'Your bank-transfer details are unavailable right now.',
        tone: ApiStateTone.info,
      );
    }

    switch (account.status) {
      case DedicatedVirtualAccountStatus.available:
        if (!account.canDisplayDetails) {
          return ApiStateCard(
            title: 'Funding account incomplete',
            message:
                'We could not confirm complete bank-transfer details. '
                'Refresh to try again.${_virtualAccountDetails(account)}',
            tone: ApiStateTone.warning,
            actionLabel: 'Refresh',
            onAction: refresh,
          );
        }
        return _availableVirtualAccountCard(account);

      case DedicatedVirtualAccountStatus.pending:
        return ApiStateCard(
          title: 'Funding account is being set up',
          message:
              'Your bank-transfer account is being set up. Refresh to check '
              'its status.${_virtualAccountDetails(account)}',
          tone: ApiStateTone.info,
          actionLabel: 'Refresh',
          onAction: refresh,
        );

      case DedicatedVirtualAccountStatus.failed:
        return ApiStateCard(
          title: 'Funding account setup failed',
          message:
              '${account.failureReason ?? 'We could not create your dedicated '
                      'account for bank transfers.'}'
              '${_virtualAccountDetails(account)}',
          tone: ApiStateTone.error,
          actionLabel: 'Refresh',
          onAction: refresh,
        );

      case DedicatedVirtualAccountStatus.notRequested:
        // No create/request operation is published, so there is no action.
        return ApiStateCard(
          title: 'Funding account not set up',
          message:
              'A dedicated account for bank transfers has not been requested '
              'for your profile yet.${_virtualAccountDetails(account)}',
          tone: ApiStateTone.blocked,
        );

      case DedicatedVirtualAccountStatus.unknown:
        apiLogger.w({
          'event': 'UNKNOWN_DVA_STATUS',
          'status': account.rawStatus,
        });
        return ApiStateCard(
          title: 'Funding account status unavailable',
          message:
              'We could not confirm the status of your funding account. '
              'Refresh to try again.',
          tone: ApiStateTone.warning,
          actionLabel: 'Refresh',
          onAction: refresh,
        );
    }
  }

  Widget _availableVirtualAccountCard(DedicatedVirtualAccountData account) {
    final accountNumber = account.accountNumber!.trim();
    final currentHome = ref.watch(userHomeProvider);
    final canCopy =
        currentHome.isDone &&
        ref.watch(authSessionProvider) != null &&
        account.canDisplayDetails;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const RoundedIcon(
                icon: IconsaxPlusLinear.bank,
                color: BocColors.blue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fund by bank transfer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Transfer to this account to top up your wallet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (account.bankName != null)
            ReceiptRow(label: 'Bank', value: account.bankName!),
          // The virtual account number is intended for the customer to copy,
          // so it is deliberately shown in full rather than masked.
          ReceiptRow(label: 'Account number', value: accountNumber),
          if (account.accountName != null)
            ReceiptRow(label: 'Account name', value: account.accountName!),
          if (account.provider != null)
            ReceiptRow(label: 'Provider', value: account.provider!),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: !canCopy
                  ? null
                  : () async {
                      final current = ref.read(userHomeProvider);
                      final session = ref.read(authSessionProvider);
                      if (session == null ||
                          session.isExpired ||
                          !current.isDone ||
                          current.data?.dedicatedVirtualAccount != account) {
                        return;
                      }
                      await Clipboard.setData(
                        ClipboardData(text: accountNumber),
                      );
                      if (mounted && ref.read(authSessionProvider) == session) {
                        showSuccessMessage('Account number copied.');
                      }
                    },
              icon: const Icon(IconsaxPlusLinear.copy, size: 18),
              label: const Text('Copy account number'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeWalletSkeleton extends StatelessWidget {
  const _HomeWalletSkeleton();

  @override
  Widget build(BuildContext context) {
    const base = BocColors.navy2;
    const highlight = Color(0xFF435B75);
    Widget bar(double width, double height) => AppShimmerBlock(
      width: width,
      height: height,
      baseColor: base,
      highlightColor: highlight,
    );
    return Semantics(
      label: 'Loading your wallet',
      liveRegion: true,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(BocSpace.lg),
          decoration: BoxDecoration(
            color: BocColors.navy,
            borderRadius: BorderRadius.circular(BocRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(130, 16),
              const SizedBox(height: BocSpace.lg),
              bar(225, 34),
              const SizedBox(height: BocSpace.lg),
              bar(155, 14),
              const SizedBox(height: BocSpace.sm),
              bar(200, 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTransactionsSkeleton extends StatelessWidget {
  const _HomeTransactionsSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading your transactions',
    liveRegion: true,
    child: ExcludeSemantics(
      child: SurfaceCard(
        child: Column(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(height: BocSpace.md),
              const Row(
                children: [
                  AppShimmerBlock(width: 40, height: 40, radius: BocRadius.sm),
                  SizedBox(width: BocSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBlock(width: 145, height: 14),
                        SizedBox(height: BocSpace.xs),
                        AppShimmerBlock(width: 95, height: 10),
                      ],
                    ),
                  ),
                  AppShimmerBlock(width: 68, height: 14),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _HomeTransactionsEmpty extends StatelessWidget {
  const _HomeTransactionsEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.smartSaveContainer,
              borderRadius: BorderRadius.circular(BocRadius.sm),
            ),
            child: SizedBox.square(
              dimension: 40,
              child: Icon(
                IconsaxPlusLinear.receipt_item,
                color: colors.smartSaveAccent,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: BocSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No transactions yet', style: theme.textTheme.titleSmall),
                const SizedBox(height: BocSpace.xxs),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTransactionRow extends StatelessWidget {
  const _HomeTransactionRow({required this.row, required this.hidden});

  final CoreAccountTransaction row;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final credit = row.type == CoreTransactionType.credit;
    final formatted = formatApiAmount(row.amount, currency: 'NGN');
    final amount = hidden
        ? '₦ ••••••'
        : formatted == null
        ? 'Unavailable'
        : '${credit ? '+' : '−'}$formatted';
    final date = row.date == null
        ? 'Date unavailable'
        : DateFormat('d MMM, h:mm a').format(row.date!.toLocal());
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () =>
              showCoreTransactionDetailSheet(context, row, hidden: hidden),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: BocSpace.md,
              vertical: BocSpace.sm,
            ),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: credit
                        ? colors.successContainer
                        : colors.errorContainer,
                    borderRadius: BorderRadius.circular(BocRadius.sm),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      credit
                          ? IconsaxPlusLinear.arrow_down_1
                          : IconsaxPlusLinear.arrow_up,
                      color: credit ? colors.successText : colors.errorText,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: BocSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.narration ?? 'Transaction',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              date,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          if (row.reversed) ...[
                            const SizedBox(width: BocSpace.xs),
                            const CoreReversedIndicator(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: BocSpace.xs),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.34,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amount,
                      style: theme.textTheme.titleSmall?.figures.copyWith(
                        color: credit ? colors.successText : colors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLimitLine extends StatelessWidget {
  const _HomeLimitLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: BocSpace.xxs),
      // Wraps the value under its label when large text leaves no room.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: BocSpace.sm,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(value, style: theme.textTheme.titleSmall?.figures),
          ],
        ),
      ),
    );
  }
}
