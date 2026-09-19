import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/private_user_state.dart';
import '../../../app/services.dart';
import '../../../utils/auth_input.dart';
import '../../account/provider/user_providers.dart';
import '../model/auth_requests.dart';
import '../model/auth_responses.dart';
import '../service/auth_service.dart';
import 'auth_session_provider.dart';
import 'fcm_token_provider.dart';
import 'identifier_verification_provider.dart';
import 'login_flow_provider.dart';
import 'post_login_bootstrap_provider.dart';
import 'recovery_providers.dart';
import 'signup_flow_provider.dart';
import 'test_otp_provider.dart';

final createFirstPinProvider =
    NotifierProvider<CreateFirstPinNotifier, NotifierState<CreateFirstPinData>>(
      CreateFirstPinNotifier.new,
    );

class CreateFirstPinNotifier
    extends Notifier<NotifierState<CreateFirstPinData>> {
  @override
  NotifierState<CreateFirstPinData> build() => const NotifierState.idle();

  Future<void> submit(String pin) async {
    if (!isStrongTransactionPin(pin)) {
      state = const NotifierState.error('Choose a PIN that is hard to guess.');
      return;
    }
    state = const NotifierState.loading();
    state = await ref
        .read(authServiceProvider)
        .createFirstPin(CreateFirstPinRequest(pin));
    if (state.isDone) {
      ref.read(userProfileProvider.notifier).markPinCreated();
      ref
          .read(authNavigationProvider.notifier)
          .publish(AuthDestination.home, mode: AuthNavigationMode.clearStack);
    }
  }
}

final changePasswordProvider =
    NotifierProvider<ChangePasswordNotifier, NotifierState<EmptyData>>(
      ChangePasswordNotifier.new,
    );

class ChangePasswordNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();
  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty || !isValidApiPassword(newPassword)) {
      state = const NotifierState.error(
        'Enter your current password and a compliant new password.',
      );
      return;
    }
    state = const NotifierState.loading();
    state = await ref
        .read(authServiceProvider)
        .changePassword(
          ChangePasswordRequest(
            currentPassword: currentPassword,
            newPassword: newPassword,
          ),
        );
  }
}

final verifyCurrentPasswordProvider =
    NotifierProvider<VerifyCurrentPasswordNotifier, NotifierState<EmptyData>>(
      VerifyCurrentPasswordNotifier.new,
    );

class VerifyCurrentPasswordNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();
  Future<void> submit(String password) async {
    if (password.isEmpty) {
      state = const NotifierState.error('Enter your current password.');
      return;
    }
    state = const NotifierState.loading();
    state = await ref
        .read(authServiceProvider)
        .verifyCurrentPassword(VerifyCurrentPasswordRequest(password));
  }
}

final changePinProvider =
    NotifierProvider<ChangePinNotifier, NotifierState<EmptyData>>(
      ChangePinNotifier.new,
    );

class ChangePinNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();
  Future<void> submit({
    required String currentPin,
    required String newPin,
  }) async {
    if (!isValidTransactionPin(currentPin) || !isStrongTransactionPin(newPin)) {
      state = const NotifierState.error(
        'Enter your current PIN and choose a hard-to-guess new PIN.',
      );
      return;
    }
    state = const NotifierState.loading();
    state = await ref
        .read(authServiceProvider)
        .changePin(ChangePinRequest(currentPin: currentPin, newPin: newPin));
  }
}

final verifyCurrentPinProvider =
    NotifierProvider<VerifyCurrentPinNotifier, NotifierState<EmptyData>>(
      VerifyCurrentPinNotifier.new,
    );

class VerifyCurrentPinNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();
  Future<void> submit(String pin) async {
    if (!isValidTransactionPin(pin)) {
      state = const NotifierState.error('Enter a valid 4-digit PIN.');
      return;
    }
    state = const NotifierState.loading();
    state = await ref
        .read(authServiceProvider)
        .verifyCurrentPin(VerifyCurrentPinRequest(pin));
  }
}

final logoutProvider =
    NotifierProvider<LogoutNotifier, NotifierState<EmptyData>>(
      LogoutNotifier.new,
    );

class LogoutNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();

  Future<void> logout() async {
    state = const NotifierState.loading();
    try {
      if (ref.read(authSessionProvider) != null) {
        state = await ref.read(authServiceProvider).logout();
      } else {
        state = const NotifierState.done(EmptyData());
      }
    } finally {
      try {
        await ref.read(authSessionProvider.notifier).clear();
      } catch (_) {
        // In-memory auth state is already cleared by the session notifier.
      }
      clearPrivateUserState(ref);
      ref.invalidate(signupFlowProvider);
      ref.invalidate(loginFlowProvider);
      ref.invalidate(passwordRecoveryProvider);
      ref.invalidate(pinRecoveryProvider);
      ref.invalidate(identifierVerificationProvider);
      ref.invalidate(postLoginBootstrapProvider);
      ref.invalidate(fcmTokenProvider);
      ref.read(testOtpProvider.notifier).clearAll();
      ref
          .read(authNavigationProvider.notifier)
          .publish(AuthDestination.login, mode: AuthNavigationMode.clearStack);
    }
  }
}
