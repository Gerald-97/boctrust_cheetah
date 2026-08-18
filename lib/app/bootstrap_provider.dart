import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helper/secure_storage.dart';
import '../module/onboarding/model/auth_flow_models.dart';
import '../module/onboarding/provider/auth_session_provider.dart';
import '../module/onboarding/provider/post_login_bootstrap_provider.dart';
import 'auth_navigation_provider.dart';
import 'preferences.dart';
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
      data: StartupGateData(stage: StartupGateStage.hydratingSession),
    );

    final result = await ref.read(authSessionProvider.notifier).hydrate();
    if (result.status != StoredSessionStatus.valid) {
      final hasSeen =
          ref.read(sharedPreferencesProvider).getBool(hasSeenOnboardingKey) ??
          false;
      final destination = hasSeen
          ? AuthDestination.login
          : AuthDestination.onboarding;
      _publish(
        destination,
        message: result.status == StoredSessionStatus.expired
            ? 'Your session has expired. Please sign in again.'
            : null,
      );
      return;
    }

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

  void _publish(AuthDestination destination, {String? message}) {
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
        .publish(
          destination,
          mode: AuthNavigationMode.clearStack,
          message: message,
        );
  }
}
