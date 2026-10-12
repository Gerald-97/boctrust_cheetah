import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../core_banking/provider/core_paged_rows.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/interest_accrual_models.dart';
import '../service/core_flex_interest_service.dart';
import '../service/core_savings_plan_service.dart';

/// Whose daily interest is read: the Flex account's or one plan's.
sealed class InterestSource {
  const InterestSource();
  const factory InterestSource.flex() = FlexInterestSource;
  const factory InterestSource.plan(String planId) = PlanInterestSource;
}

class FlexInterestSource extends InterestSource {
  const FlexInterestSource();

  @override
  bool operator ==(Object other) => other is FlexInterestSource;

  @override
  int get hashCode => 0;
}

class PlanInterestSource extends InterestSource {
  const PlanInterestSource(this.planId);
  final String planId;

  @override
  bool operator ==(Object other) =>
      other is PlanInterestSource && other.planId == planId;

  @override
  int get hashCode => planId.hashCode;
}

/// The daily interest of one source, newest first, a page at a time. Re-read
/// when the session changes so one customer's history never shows for another.
final interestHistoryProvider = NotifierProvider.autoDispose
    .family<
      InterestHistoryNotifier,
      NotifierState<PagedRows<InterestAccrual>>,
      InterestSource
    >(InterestHistoryNotifier.new);

class InterestHistoryNotifier extends PagedRowsNotifier<InterestAccrual> {
  InterestHistoryNotifier(this.source);

  final InterestSource source;

  @override
  int get pageSize => 30;

  @override
  String get loadFailure => "We couldn't load your interest history.";

  @override
  void watchScope() => ref.watch(authSessionProvider);

  /// One row per day and no id: a day already shown is not added again.
  @override
  Object? rowKey(InterestAccrual row) => row.date;

  @override
  Future<NotifierState<PagedRead<InterestAccrual>>> readPage(int page) async {
    final result = await switch (source) {
      FlexInterestSource() =>
        ref
            .read(coreFlexInterestServiceProvider)
            .getAccruals(page: page, pageSize: pageSize),
      PlanInterestSource(:final planId) =>
        ref
            .read(coreSavingsPlanServiceProvider)
            .getPlanAccruals(planId, page: page, pageSize: pageSize),
    };
    final read = result.data;
    return read == null
        ? NotifierState.error(
            result.message ?? loadFailure,
            statusCode: result.statusCode,
          )
        : NotifierState.done((rows: read.accruals, page: read.page));
  }
}
