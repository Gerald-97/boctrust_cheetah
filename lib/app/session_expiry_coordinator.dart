import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/onboarding/provider/auth_session_provider.dart';
import 'auth_navigation_provider.dart';
import 'private_user_state.dart';

final sessionExpiryCoordinatorProvider = Provider<SessionExpiryCoordinator>(
  (ref) => SessionExpiryCoordinator(ref),
);

class SessionExpiryCoordinator {
  SessionExpiryCoordinator(this._ref);

  final Ref _ref;
  Future<void>? _pending;

  Future<void> expireOnce({
    String message = 'Your session has expired. Please sign in again.',
  }) {
    return _pending ??= _expire(message).whenComplete(() => _pending = null);
  }

  Future<void> _expire(String message) async {
    try {
      await _ref.read(authSessionProvider.notifier).clear();
    } finally {
      // Before Login is published, so the next user never sees this one's data.
      clearPrivateUserState(_ref);
      _ref
          .read(authNavigationProvider.notifier)
          .publish(
            AuthDestination.login,
            mode: AuthNavigationMode.clearStack,
            message: message,
          );
    }
  }
}
