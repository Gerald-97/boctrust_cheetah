import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../helper/fcm_service.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../service/auth_service.dart';
import 'auth_session_provider.dart';

final fcmTokenProvider =
    NotifierProvider<FcmTokenNotifier, NotifierState<FcmRegistrationData>>(
      FcmTokenNotifier.new,
    );

class FcmTokenNotifier extends Notifier<NotifierState<FcmRegistrationData>> {
  bool _permissionRequested = false;

  @override
  NotifierState<FcmRegistrationData> build() =>
      const NotifierState.idle(data: FcmRegistrationData());

  Future<void> registerAfterBootstrap() async {
    if (ref.read(authSessionProvider) == null) return;
    if (!ref.read(firebaseReadyProvider)) {
      _retryable(
        'Push notifications are not configured for this build.',
        DateTime.now().toUtc(),
      );
      return;
    }
    if (state.data?.stage == FcmRegistrationStage.permissionDenied) return;
    final now = DateTime.now().toUtc();
    state = NotifierState.loading(
      data: FcmRegistrationData(
        stage: FcmRegistrationStage.registering,
        lastAttemptAt: now,
      ),
    );

    try {
      if (!_permissionRequested) {
        final settings = await ref.read(fcmServiceProvider).requestPermission();
        _permissionRequested = true;
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          state = NotifierState.done(
            FcmRegistrationData(
              stage: FcmRegistrationStage.permissionDenied,
              lastAttemptAt: now,
            ),
          );
          return;
        }
      }

      final token = await ref.read(fcmServiceProvider).getToken();
      if (token == null || token.length < 20) {
        _retryable('Push notification token is not available.', now);
        return;
      }
      await registerRefreshedToken(token, attemptedAt: now);
    } catch (_) {
      _retryable('Push notification registration will be retried.', now);
    }
  }

  Future<void> registerRefreshedToken(
    String token, {
    DateTime? attemptedAt,
  }) async {
    if (!ref.read(firebaseReadyProvider) ||
        ref.read(authSessionProvider) == null ||
        token.length < 20) {
      return;
    }
    final now = attemptedAt ?? DateTime.now().toUtc();
    state = NotifierState.loading(
      data: FcmRegistrationData(
        stage: FcmRegistrationStage.registering,
        lastAttemptAt: now,
      ),
    );
    final response = await ref
        .read(authServiceProvider)
        .updateFcmToken(UpdateFcmTokenRequest(token));
    if (response.isDone) {
      state = NotifierState.done(
        FcmRegistrationData(
          stage: FcmRegistrationStage.registered,
          lastAttemptAt: now,
        ),
        message: response.message,
        statusCode: response.statusCode,
        meta: response.meta,
      );
    } else {
      state = NotifierState.error(
        response.message ?? 'Push notification registration will be retried.',
        data: FcmRegistrationData(
          stage: FcmRegistrationStage.retryableFailure,
          lastAttemptAt: now,
        ),
        statusCode: response.statusCode,
        errorCode: response.errorCode,
        errors: response.errors,
        meta: response.meta,
        noAuth: response.noAuth,
      );
    }
  }

  void _retryable(String message, DateTime attemptedAt) {
    state = NotifierState.error(
      message,
      data: FcmRegistrationData(
        stage: FcmRegistrationStage.retryableFailure,
        lastAttemptAt: attemptedAt,
      ),
    );
  }
}
