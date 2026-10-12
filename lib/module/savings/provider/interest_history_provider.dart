import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
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
      NotifierState<List<InterestAccrual>>,
      InterestSource
    >(InterestHistoryNotifier.new);

class InterestHistoryNotifier
    extends Notifier<NotifierState<List<InterestAccrual>>> {
  InterestHistoryNotifier(this.source);

  final InterestSource source;
  int _generation = 0;
  int _page = 1;
  bool hasMore = false;
  bool loadingMore = false;

  @override
  NotifierState<List<InterestAccrual>> build() {
    ref.watch(authSessionProvider);
    _generation++;
    hasMore = false;
    loadingMore = false;
    Future.microtask(reload);
    return const NotifierState.loading();
  }

  Future<NotifierState<InterestAccrualPage>> _read(int page) =>
      switch (source) {
        FlexInterestSource() =>
          ref.read(coreFlexInterestServiceProvider).getAccruals(page: page),
        PlanInterestSource(:final planId) =>
          ref
              .read(coreSavingsPlanServiceProvider)
              .getPlanAccruals(planId, page: page),
      };

  /// Reads the first page again, dropping any later pages.
  Future<void> reload() async {
    final generation = ++_generation;
    final result = await _read(1);
    if (!ref.mounted || generation != _generation) return;
    final page = result.data;
    if (page == null) {
      state = NotifierState.error(
        result.message ?? "We couldn't load your interest history.",
        statusCode: result.statusCode,
      );
      return;
    }
    _page = 1;
    hasMore = page.page?.hasMore ?? false;
    loadingMore = false;
    state = NotifierState.done(page.accruals);
  }

  /// Adds the next page, keeping the days already shown. A failure leaves
  /// them as they are.
  Future<void> loadMore() async {
    final current = state.data;
    if (current == null || !hasMore || loadingMore) return;
    final generation = _generation;
    loadingMore = true;
    final result = await _read(_page + 1);
    if (!ref.mounted || generation != _generation) return;
    loadingMore = false;
    final page = result.data;
    if (page == null) {
      state = NotifierState.done(current);
      return;
    }
    _page++;
    hasMore = page.page?.hasMore ?? false;
    // One row per day and no id: a day already shown is not added again.
    final known = {
      for (final row in current)
        if (row.date != null) row.date,
    };
    state = NotifierState.done([
      ...current,
      for (final row in page.accruals)
        if (row.date == null || known.add(row.date)) row,
    ]);
  }
}
