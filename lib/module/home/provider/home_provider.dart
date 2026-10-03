import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/user_home_model.dart';
import '../service/home_service.dart';
import '../../../app/session_scoped_notifier.dart';

final userHomeProvider =
    NotifierProvider<UserHomeNotifier, NotifierState<UserHomeData>>(
      UserHomeNotifier.new,
    );

class UserHomeNotifier extends SessionScopedNotifier<UserHomeData> {
  @override
  String get failureMessage => 'Unable to load your account overview.';

  @override
  Future<NotifierState<UserHomeData>> fetch() =>
      ref.read(homeServiceProvider).getOwnHome();
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
