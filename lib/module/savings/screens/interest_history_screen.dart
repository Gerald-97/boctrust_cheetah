import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';

import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../core_banking/screens/paged_rows_footer.dart';
import '../../home/provider/home_provider.dart';
import '../model/interest_accrual_models.dart';
import '../provider/interest_history_provider.dart';

/// Daily interest, newest first. Opened with a plan's id as the route's
/// `entityId`, or without one for the Flex account.
class InterestHistoryScreen extends ConsumerStatefulWidget {
  const InterestHistoryScreen({super.key});

  @override
  ConsumerState<InterestHistoryScreen> createState() =>
      _InterestHistoryScreenState();
}

class _InterestHistoryScreenState extends FlowPageState<InterestHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    final planId = routeArguments.entityId;
    final source = planId == null
        ? const InterestSource.flex()
        : InterestSource.plan(planId);
    final title = planId == null
        ? 'Flex interest history'
        : 'Plan interest history';
    final capability = planId == null
        ? FeatureCapability.flexInterestView
        : FeatureCapability.savingsPlansView;
    if (!ref.watch(featureAvailabilityProvider(capability)).isAvailable) {
      return popScope(
        unavailablePage(
          UnavailableDestination(
            title: title,
            heading: 'Unavailable',
            message: 'Interest history is not available yet.',
            section: AppSection.save,
            capability: capability,
          ),
        ),
      );
    }
    final state = ref.watch(interestHistoryProvider(source));
    final notifier = ref.read(interestHistoryProvider(source).notifier);
    final history = state.data;
    return popScope(
      AppScaffold(
        title: title,
        activeSection: AppSection.save,
        onBack: back,
        onSectionSelected: goSection,
        body: RefreshIndicator(
          onRefresh: notifier.reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              BocSpace.xxs,
              BocSpace.gutter,
              BocSpace.lg,
            ).clearOfNav(context),
            children: [
              if (history == null && state.isError)
                state.statusCode == 404 && planId != null
                    ? const ApiStateCard(
                        title: 'Plan unavailable',
                        message: 'This plan is no longer available.',
                        tone: ApiStateTone.info,
                      )
                    : ApiStateCard(
                        title: 'Interest history unavailable',
                        message:
                            state.message ??
                            "We couldn't load your interest history.",
                        tone: ApiStateTone.error,
                        actionLabel: 'Retry',
                        onAction: () =>
                            ref.invalidate(interestHistoryProvider(source)),
                      )
              else if (history == null)
                const ApiLoadingSection(label: 'Loading your interest')
              else if (history.rows.isEmpty)
                const ApiStateCard(
                  title: 'Interest history',
                  message: 'No interest has been earned yet.',
                  tone: ApiStateTone.info,
                )
              else ...[
                for (final row in history.rows) ...[
                  _row(row),
                  const SizedBox(height: BocSpace.sm),
                ],
                PagedRowsFooter(rows: history, onShowMore: notifier.loadMore),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(InterestAccrual row) {
    final hidden = ref.watch(homeBalanceHiddenProvider);
    String? money(String? value) =>
        hidden ? '₦ ••••••' : formatApiAmount(value, currency: 'NGN');
    final interest = money(row.interest);
    final total = money(row.cumulativeInterest);
    final date = row.date;
    final rate = row.ratePercent;
    final theme = Theme.of(context);
    final colors = context.bocColors;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RoundedIcon(
                icon: IconsaxPlusLinear.percentage_circle,
                color: colors.successText,
                size: 40,
              ),
              const SizedBox(width: BocSpace.sm),
              Expanded(
                child: Text(
                  date == null
                      ? 'Interest'
                      : DateFormat('d MMM yyyy').format(date),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: BocSpace.md),
          Text('Interest earned', style: theme.textTheme.bodySmall),
          const SizedBox(height: BocSpace.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              interest ?? 'Unavailable',
              style: theme.textTheme.headlineSmall?.figures.copyWith(
                color: colors.successText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (rate != null || total != null) ...[
            const SizedBox(height: BocSpace.md),
            Divider(height: 1, color: colors.border),
            const SizedBox(height: BocSpace.sm),
            Wrap(
              spacing: BocSpace.sm,
              runSpacing: BocSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (rate != null) SmallPill(text: '$rate% p.a.'),
                if (total != null)
                  Text(
                    'Earned so far: $total',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
