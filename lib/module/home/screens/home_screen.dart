part of '../../app_flow/app_flow_navigator.dart';

extension HomeScreen on AppFlowNavigatorState {
  Widget _homeScreen() {
    final currentThemeMode = ref.watch(themeControllerProvider).mode;
    final profileState = ref.watch(userProfileProvider);
    final tierState = ref.watch(userTierProvider);
    final session = ref.watch(authSessionProvider);
    final profile = profileState.data;
    final tier = tierState.data;

    if (profileState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    if (tierState.status == ServiceStatus.idle && session != null) {
      Future<void>.microtask(ref.read(userTierProvider.notifier).load);
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
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: BocColors.navy,
          ),
          tooltip: 'Change theme',
          onPressed: () =>
              ref.read(themeControllerProvider.notifier).cycleMode(),
          icon: Icon(themeIcon, size: 18),
        ),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: BocColors.navy,
          ),
          tooltip: 'Notifications unavailable',
          onPressed: () => _showMessage(
            'Notifications are not available in the current User API.',
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            ref.read(userProfileProvider.notifier).load(),
            ref.read(userTierProvider.notifier).load(),
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
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      RoundedIcon(
                        icon: Icons.account_balance_wallet_outlined,
                        color: BocColors.gold,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Financial overview unavailable',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The current User API does not provide balances, savings, '
                    'transfers, payments, or transaction history. No placeholder '
                    'financial data is shown.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ),
            ),
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
}
