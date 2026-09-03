import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/user_home_model.dart';
import '../service/home_service.dart';

final userHomeProvider =
    NotifierProvider<UserHomeNotifier, NotifierState<UserHomeData>>(
      UserHomeNotifier.new,
    );

class UserHomeNotifier extends Notifier<NotifierState<UserHomeData>> {
  @override
  NotifierState<UserHomeData> build() => const NotifierState.idle();

  /// Loads the Home aggregate, keeping any previously loaded data visible
  /// while the request is in flight so a refresh never blanks the screen.
  Future<NotifierState<UserHomeData>> load() async {
    state = NotifierState.loading(data: state.data);
    final result = await ref.read(homeServiceProvider).getOwnHome();
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
  void clear() => state = const NotifierState.idle();
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
