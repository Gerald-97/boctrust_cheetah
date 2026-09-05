import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../account/provider/user_providers.dart';
import '../../home/provider/home_provider.dart';
import '../model/kyc_status_models.dart';
import '../service/kyc_service.dart';

final kycStatusProvider =
    NotifierProvider<KycStatusNotifier, NotifierState<KycStatusData>>(
      KycStatusNotifier.new,
    );

class KycStatusNotifier extends Notifier<NotifierState<KycStatusData>>
    with StaleResultGuard<NotifierState<KycStatusData>> {
  @override
  NotifierState<KycStatusData> build() {
    trackDisposal();
    return const NotifierState.idle();
  }

  /// Loads the authoritative status, keeping any previously loaded data visible
  /// while the request is in flight so a refresh never blanks the KYC cards.
  Future<NotifierState<KycStatusData>> load({bool preserveData = true}) async {
    final token = beginRequest();
    final retained = preserveData ? state.data : null;
    state = NotifierState.loading(data: retained);
    final result = await ref.read(kycServiceProvider).getStatus();
    if (!isCurrent(token)) return result;

    // Preserve the last known status on failure so a card can show it beside an
    // inline retry rather than collapsing. A failed refresh must never be read
    // as "no longer verified".
    state = result.isError && result.data == null && retained != null
        ? NotifierState.error(
            result.message ?? 'Unable to load your verification status.',
            data: retained,
            statusCode: result.statusCode,
            errorCode: result.errorCode,
            errors: result.errors,
            meta: result.meta,
            noAuth: result.noAuth,
          )
        : result;
    return state;
  }

  void clear() => state = const NotifierState.idle();
}

/// Reloads every provider that may show verification state, as one unit.
///
/// Concurrent callers share the in-flight refresh rather than issuing a second
/// round of four requests. Resume, manual Refresh, and a post-submission
/// refresh routinely land within the same second.
final kycAuthoritativeRefreshProvider = Provider<KycAuthoritativeRefresh>(
  KycAuthoritativeRefresh.new,
);

class KycAuthoritativeRefresh {
  KycAuthoritativeRefresh(this._ref);

  final Ref _ref;
  Future<void>? _inFlight;

  Future<void> call() {
    final current = _inFlight;
    if (current != null) return current;

    final attempt = _refresh().whenComplete(() => _inFlight = null);
    _inFlight = attempt;
    return attempt;
  }

  Future<void> _refresh() async {
    await Future.wait<void>([
      _ref.read(kycStatusProvider.notifier).load().then((_) {}),
      _ref.read(userProfileProvider.notifier).load().then((_) {}),
      _ref.read(userTierProvider.notifier).load().then((_) {}),
      _ref.read(userHomeProvider.notifier).load().then((_) {}),
    ]);
  }
}

/// Refreshes KYC status, profile, tier, and Home after a submission or resume.
///
/// SDK success and backend initiation mean submitted, never verified. Only the
/// providers refreshed here may move a card to a verified state.
Future<void> refreshKycAuthoritativeState(Ref ref) =>
    ref.read(kycAuthoritativeRefreshProvider)();
