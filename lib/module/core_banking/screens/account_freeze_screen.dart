import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../model/account_freeze_models.dart';
import '../model/customer_bank_account_models.dart';
import '../provider/account_freeze_provider.dart';
import '../provider/core_account_providers.dart';
import 'account_freeze_flow.dart';

/// Freeze or unfreeze each of the customer's Core accounts.
class AccountFreezeScreen extends ConsumerStatefulWidget {
  const AccountFreezeScreen({super.key});

  @override
  ConsumerState<AccountFreezeScreen> createState() =>
      _AccountFreezeScreenState();
}

class _AccountFreezeScreenState extends FlowPageState<AccountFreezeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(customerBankAccountsProvider.notifier).ensureLoaded();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref
        .watch(featureAvailabilityProvider(FeatureCapability.freezeAccount))
        .isAvailable) {
      return popScope(
        unavailablePage(
          const UnavailableDestination(
            title: 'Freeze an account',
            heading: 'Unavailable',
            message: 'Freezing an account is not available yet.',
            section: AppSection.account,
            capability: FeatureCapability.freezeAccount,
          ),
        ),
      );
    }
    final accountsState = ref.watch(customerBankAccountsProvider);
    final accounts = accountsState.data?.accounts;
    return popScope(
      AppScaffold(
        title: 'Freeze an account',
        activeSection: AppSection.account,
        onBack: back,
        onSectionSelected: goSection,
        showBottomNavigation: false,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            BocSpace.xxs,
            BocSpace.gutter,
            BocSpace.lg,
          ),
          children: [
            Text(
              'A frozen account cannot send money. You can still see its '
              'balance and history.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: BocSpace.md),
            if (accounts == null && accountsState.isError)
              ApiStateCard(
                title: 'Could not load your accounts',
                message: accountsState.message ?? 'Please try again.',
                tone: ApiStateTone.error,
                actionLabel: 'Retry',
                onAction: ref.read(customerBankAccountsProvider.notifier).load,
              )
            else if (accounts == null)
              const ApiLoadingSection(label: 'Loading your accounts')
            else if (accounts.isEmpty)
              const ApiStateCard(
                title: 'No accounts yet',
                message: 'You have no accounts to freeze.',
                tone: ApiStateTone.info,
              )
            else
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: BocSpace.sm),
                  child: _AccountFreezeRow(
                    account: account,
                    onContactSupport: () => go(AppRoutes.support),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _AccountFreezeRow extends ConsumerWidget {
  const _AccountFreezeRow({
    required this.account,
    required this.onContactSupport,
  });

  final CustomerBankAccount account;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.bocColors;
    final number = account.accountNumber;
    final freeze = ref.watch(accountFreezeProvider(number));
    final bankFrozen =
        ref.watch(accountFreezeMemoryProvider)[number] == CoreFrozenBy.admin ||
        freeze.phase == AccountFreezePhase.bankFrozen;
    final frozen = account.status == CoreAccountStatus.frozen;
    final unconfirmed = freeze.errorKind == AccountFreezeErrorKind.unconfirmed;
    return Container(
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
              Expanded(
                child: Text(
                  account.productName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _status(account.status),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.xxs),
          Text(
            maskedAccountNumber(number),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (unconfirmed) ...[
            const SizedBox(height: BocSpace.xs),
            Text(
              freeze.message ?? kFreezeUnconfirmedMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.errorText,
              ),
            ),
          ],
          if (frozen && bankFrozen) ...[
            const SizedBox(height: BocSpace.xs),
            Text(kFreezeBankFrozenMessage, style: theme.textTheme.bodySmall),
            const SizedBox(height: BocSpace.sm),
            SecondaryButton(
              label: 'Contact support',
              onPressed: onContactSupport,
            ),
          ] else if (unconfirmed) ...[
            const SizedBox(height: BocSpace.sm),
            SecondaryButton(
              label: 'Check again',
              onPressed: () => ref
                  .read(accountFreezeProvider(number).notifier)
                  .refreshStatus(),
            ),
          ] else if (account.isActive) ...[
            const SizedBox(height: BocSpace.sm),
            SecondaryButton(
              label: 'Freeze account',
              isLoading: freeze.isBusy,
              onPressed: freeze.isBusy
                  ? null
                  : () => openFreezeFlow(context, ref, number),
            ),
          ] else if (frozen) ...[
            const SizedBox(height: BocSpace.sm),
            SecondaryButton(
              label: 'Request unfreeze',
              isLoading: freeze.isBusy,
              onPressed: freeze.isBusy
                  ? null
                  : () => openUnfreezeFlow(context, ref, number),
            ),
          ],
        ],
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
