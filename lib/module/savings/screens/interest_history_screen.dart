import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
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
    final state = ref.watch(interestHistoryProvider(source));
    final notifier = ref.read(interestHistoryProvider(source).notifier);
    final rows = state.data;
    return popScope(
      AppScaffold(
        title: planId == null
            ? 'Flex interest history'
            : 'Plan interest history',
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
              if (rows == null && state.isError)
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
              else if (rows == null)
                const ApiLoadingSection(label: 'Loading your interest')
              else if (rows.isEmpty)
                const ApiStateCard(
                  title: 'Interest history',
                  message: 'No interest has been earned yet.',
                  tone: ApiStateTone.info,
                )
              else ...[
                for (final row in rows) _row(row),
                if (notifier.hasMore)
                  Center(
                    child: TextButton(
                      onPressed: notifier.loadMore,
                      child: const Text('Show more'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(InterestAccrual row) {
    final interest = formatApiAmount(row.interest, currency: 'NGN');
    final total = formatApiAmount(row.cumulativeInterest, currency: 'NGN');
    final date = row.date;
    final rate = row.ratePercent;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        date == null ? 'Interest' : DateFormat('d MMM yyyy').format(date),
      ),
      subtitle: Text(
        [
          if (rate != null) '$rate% p.a.',
          if (total != null) 'So far: $total',
        ].join(' · '),
      ),
      trailing: Text(interest ?? 'Unavailable'),
    );
  }
}
