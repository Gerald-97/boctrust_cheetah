import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/secure_storage.dart';
import '../module/onboarding/model/auth_flow_models.dart';
import '../module/onboarding/provider/auth_session_provider.dart';
import '../module/onboarding/provider/fcm_token_provider.dart';
import '../module/onboarding/provider/post_login_bootstrap_provider.dart';
import 'auth_navigation_provider.dart';
import 'preferences.dart';
import 'private_user_state.dart';
import 'services.dart';

final startupGateProvider =
    NotifierProvider<StartupGateNotifier, NotifierState<StartupGateData>>(
      StartupGateNotifier.new,
    );

class StartupGateNotifier extends Notifier<NotifierState<StartupGateData>> {
  bool _started = false;
  bool _publishedTerminalIntent = false;

  @override
  NotifierState<StartupGateData> build() =>
      const NotifierState.idle(data: StartupGateData());

  Future<void> start() async {
    if (_started) return;
    _started = true;
    state = const NotifierState.loading(
      data: StartupGateData(stage: StartupGateStage.clearingSession),
    );

    // A new process never resumes a stored session: every launch signs in
    // again. If the delete fails, memory stays empty, private routes stay
    // closed, and the interceptor refuses the leftover token.
    try {
      await ref.read(authSessionProvider.notifier).clear();
      await ref.read(secureStorageProvider).deleteLegacySessionKeys();
    } catch (_) {
      // Routing below is the same either way.
    }
    final hasSeen =
        ref.read(sharedPreferencesProvider).getBool(hasSeenOnboardingKey) ??
        false;
    _publish(hasSeen ? AuthDestination.login : AuthDestination.onboarding);
  }

  Future<void> startAfterLogin() async {
    _started = true;
    _publishedTerminalIntent = false;
    // A new sign-in may be a different account from the last one this process
    // held, whichever way that session ended.
    clearPrivateUserState(ref);
    ref.invalidate(postLoginBootstrapProvider);
    ref.invalidate(fcmTokenProvider);
    ref
        .read(authNavigationProvider.notifier)
        .publish(
          AuthDestination.bootstrap,
          mode: AuthNavigationMode.clearStack,
        );
    await _loadProfile();
  }

  Future<void> retryProfile() => _loadProfile();

  Future<void> _loadProfile() async {
    state = const NotifierState.loading(
      data: StartupGateData(stage: StartupGateStage.loadingProfile),
    );
    final destination = await ref
        .read(postLoginBootstrapProvider.notifier)
        .load();
    final bootstrap = ref.read(postLoginBootstrapProvider);
    if (destination == null) {
      state = NotifierState.error(
        bootstrap.message ?? 'Unable to load your profile.',
        data: const StartupGateData(stage: StartupGateStage.profileError),
        statusCode: bootstrap.statusCode,
        errorCode: bootstrap.errorCode,
        errors: bootstrap.errors,
        meta: bootstrap.meta,
        noAuth: bootstrap.noAuth,
      );
      return;
    }
    _publish(destination);
  }

  void _publish(AuthDestination destination) {
    if (_publishedTerminalIntent) return;
    _publishedTerminalIntent = true;
    state = NotifierState.done(
      StartupGateData(
        stage: StartupGateStage.complete,
        destination: destination,
      ),
    );
    ref
        .read(authNavigationProvider.notifier)
        .publish(destination, mode: AuthNavigationMode.clearStack);
  }
}
