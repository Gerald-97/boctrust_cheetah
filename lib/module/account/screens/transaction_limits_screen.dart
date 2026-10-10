import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../model/transaction_limit_models.dart';
import '../provider/user_providers.dart';
import '../provider/transaction_limit_provider.dart';

/// The customer's effective transfer and bill-payment limits, read only.
/// Changing them is a separate capability.
class TransactionLimitsScreen extends ConsumerStatefulWidget {
  const TransactionLimitsScreen({super.key});

  @override
  ConsumerState<TransactionLimitsScreen> createState() =>
      _TransactionLimitsScreenState();
}

class _TransactionLimitsScreenState
    extends FlowPageState<TransactionLimitsScreen> {
  @override
  Widget build(BuildContext context) {
    if (!ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.transactionLimitsView),
        )
        .isAvailable) {
      return popScope(
        unavailablePage(
          const UnavailableDestination(
            title: 'Transaction limits',
            heading: 'Unavailable',
            message: 'Transaction limits are not available yet.',
            section: AppSection.account,
            capability: FeatureCapability.transactionLimitsView,
          ),
        ),
      );
    }
    final limits = ref.watch(transactionLimitsProvider);
    return popScope(
      AppScaffold(
        title: 'Transaction limits',
        activeSection: AppSection.account,
        onBack: back,
        onSectionSelected: goSection,
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(transactionLimitsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              BocSpace.xxs,
              BocSpace.gutter,
              BocSpace.lg,
            ).clearOfNav(context),
            children: [
              switch (limits) {
                AsyncData(:final value) when value.data != null => _limits(
                  value.data!,
                ),
                // Tier 0 has no limits to show until BVN and liveness. Core's
                // tier can lag the User Service's, so a customer the User
                // Service already verified sees Core's own reason instead.
                AsyncData(:final value)
                    when value.statusCode == 403 &&
                        ref.watch(userTierProvider).data?.currentTier == 0 =>
                  ApiStateCard(
                    title: 'Verify your identity',
                    message:
                        'Verify your BVN and complete a liveness check to '
                        'see your limits.',
                    tone: ApiStateTone.info,
                    actionLabel: 'Verify now',
                    onAction: () => go(AppRoutes.tier1Bvn),
                  ),
                AsyncData(:final value) => ApiStateCard(
                  title: 'Limits unavailable',
                  message: value.message ?? "We couldn't load your limits.",
                  tone: ApiStateTone.error,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(transactionLimitsProvider),
                ),
                _ => const ApiLoadingSection(label: 'Loading your limits'),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _limits(TransactionLimits limits) {
    String money(String? naira) =>
        formatApiAmount(naira, currency: 'NGN') ?? 'Unavailable';
    return BocSummaryGrid(
      items: [
        (label: 'Tier', value: 'Tier ${limits.tier}'),
        for (final (label, limit) in [
          ('Single transfer', limits.singleTransfer),
          ('Daily transfers', limits.dailyTransfer),
          ('Single bill payment', limits.singleBillPayment),
        ])
          (label: label, value: money(limit.effective)),
      ],
    );
  }
}
