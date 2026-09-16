import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/user_home_model.dart';
import '../service/home_service.dart';
import '../../onboarding/provider/auth_session_provider.dart';

final userHomeProvider =
    NotifierProvider<UserHomeNotifier, NotifierState<UserHomeData>>(
      UserHomeNotifier.new,
    );

class UserHomeNotifier extends Notifier<NotifierState<UserHomeData>>
    with StaleResultGuard<NotifierState<UserHomeData>> {
  @override
  NotifierState<UserHomeData> build() {
    trackDisposal();
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != next) clear();
    });
    return const NotifierState.idle();
  }

  Future<NotifierState<UserHomeData>>? _inFlight;

  /// Loads the Home aggregate, keeping any previously loaded data visible
  /// while the request is in flight so a refresh never blanks the screen.
  Future<NotifierState<UserHomeData>> load() {
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) {
      clear();
      return Future.value(state);
    }
    return _inFlight ??= _load(session.accessToken);
  }

  Future<NotifierState<UserHomeData>> _load(String accessToken) async {
    final token = beginRequest();
    state = NotifierState.loading(data: state.data);
    final result = await ref.read(homeServiceProvider).getOwnHome();
    if (!ref.mounted || !isCurrent(token)) return const NotifierState.idle();
    _inFlight = null;
    final session = ref.read(authSessionProvider);
    if (session == null ||
        session.isExpired ||
        session.accessToken != accessToken) {
      clear();
      return const NotifierState.idle();
    }
    // Preserve stale data on failure so the section can show it beside an
    // inline retry rather than collapsing to an empty card.
    state = result.isError && result.data == null && state.data != null
        ? NotifierState.error(
            result.message ?? 'Unable to load your account overview.',
            data: state.data,
            statusCode: result.statusCode,
            errorCode: result.errorCode,
            errors: result.errors,
            meta: result.meta,
            noAuth: result.noAuth,
          )
        : result;
    return state;
  }

  /// Clears private balance data. Called on logout and handled session expiry
  /// so a second user can never see the previous user's balances.
  void clear() {
    beginRequest();
    _inFlight = null;
    state = const NotifierState.idle();
  }
}

/// Local-only visibility toggle for the Home balance hero.
///
/// Not persisted and not sent to the API — it only hides the value on screen.
final homeBalanceHiddenProvider =
    NotifierProvider<HomeBalanceHiddenNotifier, bool>(
      HomeBalanceHiddenNotifier.new,
    );

class HomeBalanceHiddenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}
