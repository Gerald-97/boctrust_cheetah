part of '../../app_flow/app_flow_navigator.dart';

extension HomeScreen on AppFlowNavigatorState {
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
    final canUpgrade =
        tier != null && topTier != null && tier.currentTier < topTier;
    final colors = context.bocColors;
    final theme = Theme.of(context);

    return AppScaffold(
      titleWidget: const BocLogo(height: 26),
      activeSection: AppSection.home,
      onSectionSelected: _goSection,
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => _go(AppScreen.notifications),
          icon: const Icon(Icons.notifications_none_rounded),
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
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xs,
            BocSpace.gutter,
            BocSpace.lg,
          ),
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
            if (homeState.data?.verification['nextAction'] ==
                'verify_phone_number') ...[
              const SizedBox(height: BocSpace.sm),
              ApiStateCard(
                title: 'Verify your phone number',
                message:
                    'Add and confirm your phone number to complete your '
                    'account setup.',
                tone: ApiStateTone.info,
                actionLabel: 'Verify',
                onAction: () => _showIdentifierVerificationSheet(
                  phone: true,
                  initialIdentifier: profile?.phoneNumber,
                ),
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
                    (Icons.add_rounded, 'Add money', AppScreen.addMoney),
                    (Icons.send_rounded, 'Send', AppScreen.sendHub),
                    (Icons.savings_outlined, 'Save', AppScreen.saveHub),
                    (Icons.receipt_long_outlined, 'Pay', AppScreen.payments),
                  ])
                    Expanded(
                      child: QuickAction(
                        icon: icon,
                        label: label,
                        background: colors.smartSaveContainer,
                        foreground: theme.brightness == Brightness.dark
                            ? colors.textPrimary
                            : BocColors.navy,
                        onTap: () => _go(screen),
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
                              Icons.verified_user_outlined,
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
                      onPressed: () => _go(AppScreen.tiers),
                    ),
                  ],
                ),
              ),
            ],
            // Funding details follow the everyday actions, as in the design.
            if (homeState.data case final home?) ...[
              const SizedBox(height: BocSpace.sm),
              _dedicatedVirtualAccountCard(home.dedicatedVirtualAccount),
            ],
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
        return [const ApiLoadingSection(label: 'Loading your wallet')];
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

    return BalanceCard(
      label: 'Wallet balance',
      balance: available,
      hidden: hidden,
      onToggle: () => ref.read(homeBalanceHiddenProvider.notifier).toggle(),
      accountNumber: accountNumber,
      bankName: bankName,
      onCopyAccountNumber: accountNumber == null || funding == null
          ? null
          : () => _copyFundingAccountNumber(funding),
      tier: ref.watch(userTierProvider).data?.currentTier,
      loading: loading,
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
      _showSuccessMessage('Account number copied.');
    }
  }

  Widget _dedicatedVirtualAccountCard(DedicatedVirtualAccountData? account) {
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
                'Refresh to try again.',
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
              'Your bank-transfer account is being set up. Refresh to check its status.',
          tone: ApiStateTone.info,
          actionLabel: 'Refresh',
          onAction: refresh,
        );

      case DedicatedVirtualAccountStatus.failed:
        return ApiStateCard(
          title: 'Funding account setup failed',
          message:
              account.failureReason ??
              'We could not create your dedicated account for bank transfers.',
          tone: ApiStateTone.error,
          actionLabel: 'Refresh',
          onAction: refresh,
        );

      case DedicatedVirtualAccountStatus.notRequested:
        // No create/request operation is published, so there is no action.
        return const ApiStateCard(
          title: 'Funding account not set up',
          message:
              'A dedicated account for bank transfers has not been requested '
              'for your profile yet.',
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
                icon: Icons.account_balance_outlined,
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
                        _showSuccessMessage('Account number copied.');
                      }
                    },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy account number'),
            ),
          ),
        ],
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
