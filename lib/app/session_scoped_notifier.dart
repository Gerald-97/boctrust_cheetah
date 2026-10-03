import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/onboarding/provider/auth_session_provider.dart';
import 'services.dart';

/// A private read tied to the signed-in session.
///
/// The access token that started a load must still be current when it lands,
/// overlapping loads share one request, a failed refresh keeps the last good
/// data beside the error, and [clear] drops state and any in-flight response,
/// so a second user never sees the previous user's data.
abstract class SessionScopedNotifier<T> extends Notifier<NotifierState<T>>
    with StaleResultGuard<NotifierState<T>> {
  Future<NotifierState<T>>? _inFlight;

  /// Shown when a refresh fails without a message of its own.
  String get failureMessage;

  Future<NotifierState<T>> fetch();

  @protected
  bool get isLoadInFlight => _inFlight != null;

  @override
  NotifierState<T> build() {
    trackDisposal();
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != next) clear();
    });
    return const NotifierState.idle();
  }

  Future<NotifierState<T>> load() {
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) {
      clear();
      return Future.value(state);
    }
    return _inFlight ??= _load(session.accessToken);
  }

  Future<NotifierState<T>> _load(String accessToken) async {
    final token = beginRequest();
    final retained = state.data;
    state = NotifierState.loading(data: retained);
    final result = await fetch();
    if (!ref.mounted || !isCurrent(token)) return const NotifierState.idle();
    _inFlight = null;
    final session = ref.read(authSessionProvider);
    if (session == null ||
        session.isExpired ||
        session.accessToken != accessToken) {
      clear();
      return const NotifierState.idle();
    }
    state = result.isError && result.data == null && retained != null
        ? NotifierState.error(
            result.message ?? failureMessage,
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

  void clear() {
    beginRequest();
    _inFlight = null;
    state = const NotifierState.idle();
  }
}
