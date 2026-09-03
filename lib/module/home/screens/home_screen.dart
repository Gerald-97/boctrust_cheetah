part of '../../app_flow/app_flow_navigator.dart';

extension HomeScreen on AppFlowNavigatorState {
  Widget _homeScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final profileState = ref.watch(userProfileProvider);
    final tierState = ref.watch(userTierProvider);
    final homeState = ref.watch(userHomeProvider);
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

    final themeIcon = switch (currentThemeMode) {
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
      AppThemeMode.system => Icons.settings_brightness_outlined,
    };
    final displayName = profile?.firstName?.trim().isNotEmpty == true
        ? profile!.firstName!.trim()
        : 'there';
    final identifier =
        profile?.email ??
        profile?.phoneNumber ??
        session?.email ??
        session?.phoneNumber ??
        'Account details unavailable';
    final tierSummary = tier?.currentTierSummary;

    return AppScaffold(
      titleWidget: const BocLogo(height: 26),
      activeSection: AppSection.home,
      onSectionSelected: _goSection,
      actions: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Change theme',
          onPressed: () =>
              ref.read(themeControllerProvider.notifier).cycleMode(),
          icon: Icon(themeIcon, size: 18),
        ),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          tooltip: 'Notifications',
          onPressed: () => _go(AppScreen.notifications),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
            ref.read(userHomeProvider.notifier).load(),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              'Welcome, $displayName',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              identifier,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 18),
            if (profileState.isError || tierState.isError) ...[
              MaterialBanner(
                content: Text(
                  profileState.message ??
                      tierState.message ??
                      'Unable to refresh your account details.',
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await Future.wait([
                        ref.read(userProfileProvider.notifier).load(),
                        ref.read(userTierProvider.notifier).load(),
                      ]);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            SurfaceCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoundedIcon(
                    icon: profile?.isVerifiedAccount == true
                        ? Icons.verified_user_outlined
                        : Icons.person_outline_rounded,
                    color: profile?.isVerifiedAccount == true
                        ? BocColors.green
                        : BocColors.gold,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'Your account',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          profile == null
                              ? 'Loading verified profile details…'
                              : 'Tier ${profile.tier} · '
                                    '${profile.isVerifiedAccount ? 'Verified' : 'Verification pending'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () => _go(AppScreen.account),
                          icon: const Icon(Icons.manage_accounts_outlined),
                          label: const Text('Manage account'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ..._homeWalletSection(homeState),
            const SizedBox(height: 14),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const RoundedIcon(
                        icon: Icons.shield_outlined,
                        color: BocColors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tierSummary?.tierLabel ?? 'Account tier',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tierSummary != null) ...[
                    LimitRow(
                      label: 'Daily transfer limit',
                      value: tierSummary.dailyTransferLimit.displayValue,
                    ),
                    LimitRow(
                      label: 'Max wallet balance',
                      value: tierSummary.maxWalletBalance.displayValue,
                    ),
                  ] else
                    Text(
                      tierState.isLoading
                          ? 'Loading tier details…'
                          : 'Tier details are unavailable.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _go(AppScreen.tiers),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('View account tiers'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Wallet hero and dedicated virtual account.
  ///
  /// Renders only API-authoritative values. A missing or unknown state is shown
  /// as such — this section never substitutes a placeholder balance or account.
  List<Widget> _homeWalletSection(NotifierState<UserHomeData> homeState) {
    final home = homeState.data;

    if (home == null) {
      if (homeState.isLoading || homeState.status == ServiceStatus.idle) {
        return [const ApiLoadingSection(label: 'Loading your wallet')];
      }
      return [
        ApiStateCard(
          title: 'Wallet unavailable',
          message:
              homeState.message ?? 'We could not load your account overview.',
          tone: ApiStateTone.error,
          actionLabel: 'Retry',
          onAction: () => ref.read(userHomeProvider.notifier).load(),
        ),
      ];
    }

    return [
      if (homeState.isError) ...[
        ApiStateCard(
          title: 'Showing your last known balance',
          message: homeState.message ?? 'We could not refresh your wallet.',
          tone: ApiStateTone.warning,
          actionLabel: 'Retry',
          onAction: () => ref.read(userHomeProvider.notifier).load(),
        ),
        const SizedBox(height: 14),
      ],
      _flexWalletCard(home.flexWallet, loading: homeState.isLoading),
      const SizedBox(height: 14),
      _dedicatedVirtualAccountCard(home.dedicatedVirtualAccount),
    ];
  }

  Widget _flexWalletCard(FlexWalletData? wallet, {required bool loading}) {
    if (wallet == null) {
      return const ApiStateCard(
        title: 'No wallet yet',
        message:
            'Your Flex wallet has not been created. It will appear here once '
            'it is ready.',
        tone: ApiStateTone.info,
      );
    }

    final hidden = ref.watch(homeBalanceHiddenProvider);
    final available = formatApiAmount(
      wallet.availableBalance,
      currency: wallet.currency,
    );
    final ledger = formatApiAmount(
      wallet.ledgerBalance,
      currency: wallet.currency,
    );
    final status = wallet.status;

    return Padding(
      // BalanceCard carries its own page-edge margin; this section is already
      // inset by the surrounding ListView padding.
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: BalanceCard(
        label: 'Flex wallet balance',
        balance: available,
        hidden: hidden,
        onToggle: () => ref.read(homeBalanceHiddenProvider.notifier).toggle(),
        secondaryLabel: ledger == null ? null : 'Ledger balance',
        secondaryValue: ledger,
        // Surface a non-active wallet status; it never enables an action.
        statusLabel: wallet.isActive || status == null
            ? null
            : 'Wallet status: $status',
        loading: loading,
      ),
    );
  }

  Widget _dedicatedVirtualAccountCard(DedicatedVirtualAccountData? account) {
    Future<void> refresh() => ref.read(userHomeProvider.notifier).load();

    if (account == null) {
      return const ApiStateCard(
        title: 'No funding account',
        message: 'You do not have a dedicated account for bank transfers yet.',
        tone: ApiStateTone.info,
      );
    }

    switch (account.status) {
      case DedicatedVirtualAccountStatus.available:
        if (!account.canDisplayDetails) {
          return ApiStateCard(
            title: 'Funding account incomplete',
            message:
                'Your funding account is marked available but no account '
                'number was returned. Refresh to try again.',
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
              'We are still creating your dedicated account for bank '
              'transfers. This usually takes a few minutes.',
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
    final accountNumber = account.accountNumber!;
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
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: accountNumber));
                _showSuccessMessage('Account number copied.');
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
