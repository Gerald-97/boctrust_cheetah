import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/biometric_auth_service.dart';
import '../../../helper/biometric_login_storage.dart';
import '../../../utils/auth_input.dart';
import '../../account/provider/user_providers.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../model/remembered_biometric_profile.dart';
import '../service/auth_service.dart';
import 'auth_session_provider.dart';
import 'login_flow_provider.dart';

enum BiometricLoginPhase {
  hydrating,
  unavailable,
  disabled,
  verifyingPassword,
  awaitingDeviceVerification,
  confirmingBiometric,
  enabling,
  enabled,
  authenticating,
  clearing,
  error,
}

/// Biometric login state. Holds the non-secret remembered profile only; never
/// a password or token.
class BiometricLoginState {
  const BiometricLoginState({
    required this.phase,
    this.profile,
    this.presentation,
    this.message,
  });

  final BiometricLoginPhase phase;
  final RememberedBiometricProfile? profile;
  final BiometricPresentation? presentation;
  final String? message;

  bool get isBusy => switch (phase) {
    BiometricLoginPhase.verifyingPassword ||
    BiometricLoginPhase.awaitingDeviceVerification ||
    BiometricLoginPhase.confirmingBiometric ||
    BiometricLoginPhase.enabling ||
    BiometricLoginPhase.authenticating ||
    BiometricLoginPhase.clearing => true,
    _ => false,
  };

  bool get isEnabled => profile != null;

  BiometricLoginState copyWith({
    BiometricLoginPhase? phase,
    String? message,
    bool clearMessage = false,
  }) => BiometricLoginState(
    phase: phase ?? this.phase,
    profile: profile,
    presentation: presentation,
    message: clearMessage ? null : message ?? this.message,
  );
}

class BiometricOperationResult {
  const BiometricOperationResult({
    required this.succeeded,
    this.cancelled = false,
    this.message,
  });

  const BiometricOperationResult.cancelled()
    : succeeded = false,
      cancelled = true,
      message = null;

  final bool succeeded;
  final bool cancelled;
  final String? message;
}

final biometricLoginProvider =
    NotifierProvider<BiometricLoginNotifier, BiometricLoginState>(
      BiometricLoginNotifier.new,
    );

class BiometricLoginNotifier extends Notifier<BiometricLoginState> {
  static const _otpStages = {
    LoginFlowStage.choosingNewDeviceChannel,
    LoginFlowStage.requestingNewDeviceOtp,
    LoginFlowStage.awaitingNewDeviceOtp,
    LoginFlowStage.verifyingNewDevice,
    LoginFlowStage.retryingAfterDeviceApproval,
  };

  int _operation = 0;
  bool _disposed = false;
  Future<void>? _hydration;

  BiometricLoginStorage get _storage => ref.read(biometricLoginStorageProvider);
  BiometricAuthService get _auth => ref.read(biometricAuthServiceProvider);

  @override
  BiometricLoginState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _operation++;
    });
    ref.listen(loginFlowProvider, (_, next) {
      if (state.phase == BiometricLoginPhase.authenticating &&
          _otpStages.contains(next.data?.stage)) {
        state = state.copyWith(
          phase: BiometricLoginPhase.awaitingDeviceVerification,
        );
      }
    });
    Future.microtask(hydrate);
    return const BiometricLoginState(phase: BiometricLoginPhase.hydrating);
  }

  /// Loads capability and enrollment. Concurrent callers share one load.
  Future<void> hydrate() =>
      _hydration ??= _hydrate().whenComplete(() => _hydration = null);

  Future<void> _hydrate() async {
    if (_disposed || state.isBusy) return;
    final token = _operation;
    final capability = await _auth.checkCapability();
    final enrollment = await _storage.loadValidEnrollment();
    if (!_isCurrent(token) || state.isBusy) return;
    if (!capability.supported) {
      // Biometrics were removed from the device: the enrollment cannot be used.
      if (enrollment != null) await _storage.clearEnrollment();
      if (!_isCurrent(token)) return;
      state = BiometricLoginState(
        phase: BiometricLoginPhase.unavailable,
        message: capability.reason,
      );
      return;
    }
    state = BiometricLoginState(
      phase: enrollment == null
          ? BiometricLoginPhase.disabled
          : BiometricLoginPhase.enabled,
      profile: enrollment?.profile,
      presentation: capability.presentation,
    );
  }

  /// Turns biometric login on for the signed-in customer.
  Future<BiometricOperationResult> enable(String currentPassword) async {
    if (state.isBusy) return _busy;
    final session = ref.read(authSessionProvider);
    final profile = ref.read(userProfileProvider).data;
    final rawIdentifier = switch (session?.identifierType) {
      IdentifierType.email => session?.email,
      IdentifierType.phoneNumber => session?.phoneNumber,
      _ => null,
    };
    final identifier = normalizeIdentifier(rawIdentifier ?? '');
    final firstName = profile?.firstName?.trim() ?? '';
    if (session == null ||
        profile == null ||
        profile.userId != session.userId ||
        firstName.isEmpty ||
        !isValidIdentifier(identifier, session.identifierType)) {
      return _fail(
        'Your profile is still loading. Please try again in a moment.',
      );
    }
    if (currentPassword.isEmpty) {
      return _fail('Enter your current password.');
    }

    final token = _begin(BiometricLoginPhase.verifyingPassword);
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    final presentation = capability.presentation;
    if (!capability.supported || presentation == null) {
      return _end(
        BiometricLoginState(
          phase: BiometricLoginPhase.unavailable,
          message: capability.reason,
        ),
        BiometricOperationResult(succeeded: false, message: capability.reason),
      );
    }

    final verified = await ref
        .read(authServiceProvider)
        .verifyCurrentPassword(VerifyCurrentPasswordRequest(currentPassword));
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (!verified.isDone) {
      final message = verified.noAuth || verified.statusCode == 401
          ? 'That password is incorrect.'
          : verified.message ?? 'We could not confirm your password.';
      return _restore(
        BiometricOperationResult(succeeded: false, message: message),
      );
    }

    state = state.copyWith(phase: BiometricLoginPhase.confirmingBiometric);
    final outcome = await _auth.authenticate(
      reason: 'Confirm to turn on biometric login for BOCTRUST',
    );
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (outcome != BiometricAuthOutcome.success) {
      return _restore(_resultFor(outcome));
    }

    state = state.copyWith(phase: BiometricLoginPhase.enabling);
    final remembered = RememberedBiometricProfile(
      userId: session.userId,
      identifier: identifier,
      identifierType: session.identifierType,
      firstName: firstName,
      biometricType: presentation,
    );
    try {
      await _storage.enable(
        profile: remembered,
        identifier: identifier,
        password: currentPassword,
      );
    } on BiometricStorageException catch (error) {
      if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
      return _end(
        BiometricLoginState(
          phase: BiometricLoginPhase.disabled,
          presentation: presentation,
          message: error.message,
        ),
        BiometricOperationResult(succeeded: false, message: error.message),
      );
    }
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    return _end(
      BiometricLoginState(
        phase: BiometricLoginPhase.enabled,
        profile: remembered,
        presentation: presentation,
      ),
      const BiometricOperationResult(succeeded: true),
    );
  }

  /// Turns biometric login off. Confirms with biometrics when the device can;
  /// otherwise the signed-in session authorizes it.
  Future<BiometricOperationResult> disable() async {
    if (state.isBusy) return _busy;
    final token = _begin(BiometricLoginPhase.confirmingBiometric);
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (capability.supported) {
      final outcome = await _auth.authenticate(
        reason: 'Confirm to turn off biometric login for BOCTRUST',
      );
      if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
      if (outcome != BiometricAuthOutcome.success) {
        return _restore(_resultFor(outcome));
      }
    }
    await _clear(token);
    return const BiometricOperationResult(succeeded: true);
  }

  /// Signs in to the remembered account with a typed password.
  Future<BiometricOperationResult> loginWithPassword(String password) async {
    final profile = state.profile;
    if (profile == null) return _fail('Sign in with your email or phone.');
    if (state.isBusy) return _busy;
    if (password.isEmpty) return _fail('Enter your password.');
    final token = _begin(BiometricLoginPhase.authenticating);
    final result = await ref
        .read(loginFlowProvider.notifier)
        .login(profile.identifier, password);
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (result.isCompleted && result.identifier == profile.identifier) {
      // Recovers an enrollment whose password was changed elsewhere.
      try {
        await _storage.replaceCredential(
          identifier: result.identifier,
          password: password,
        );
      } on BiometricStorageException {
        // The customer is signed in; biometric login keeps the old password.
      }
    }
    return _restore(_resultForLogin(result));
  }

  /// Signs in to the remembered account with the saved credential.
  Future<BiometricOperationResult> loginWithBiometrics() async {
    if (state.profile == null) {
      return _fail('Sign in with your email or phone.');
    }
    if (state.isBusy) return _busy;
    final token = _begin(BiometricLoginPhase.authenticating);
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (!capability.supported) {
      await _storage.clearEnrollment();
      if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
      return _end(
        BiometricLoginState(
          phase: BiometricLoginPhase.unavailable,
          message: capability.reason,
        ),
        BiometricOperationResult(succeeded: false, message: capability.reason),
      );
    }
    final outcome = await _auth.authenticate(reason: 'Sign in to BOCTRUST');
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (outcome != BiometricAuthOutcome.success) {
      return _restore(_resultFor(outcome));
    }
    final credential = await _storage.readCredentialAfterAuthentication();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (credential == null) {
      const message =
          'Biometric login was reset on this device. Sign in with your password.';
      return _end(
        BiometricLoginState(
          phase: BiometricLoginPhase.disabled,
          presentation: state.presentation,
          message: message,
        ),
        const BiometricOperationResult(succeeded: false, message: message),
      );
    }
    final result = await ref
        .read(loginFlowProvider.notifier)
        .login(credential.identifier, credential.password);
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (result.outcome == LoginAttemptOutcome.invalidCredentials) {
      // Never loop the prompt: ask for the current password instead.
      return _restore(
        const BiometricOperationResult(
          succeeded: false,
          message:
              'Your saved password no longer works. Enter your current '
              'password or reset it.',
        ),
      );
    }
    return _restore(_resultForLogin(result));
  }

  /// The single cleanup entry point for other notifiers. With
  /// [onlyForIdentifier], clears only when it matches the remembered account.
  Future<void> forgetEnrollment({String? onlyForIdentifier}) async {
    if (onlyForIdentifier != null) {
      final remembered =
          state.profile ?? (await _storage.loadValidEnrollment())?.profile;
      if (remembered == null ||
          normalizeIdentifier(onlyForIdentifier) != remembered.identifier) {
        return;
      }
    }
    cancelActiveOperation();
    await _clear(_begin(BiometricLoginPhase.clearing));
  }

  /// Abandons any in-flight prompt or login so its late result is ignored.
  void cancelActiveOperation() {
    if (!state.isBusy) return;
    final wasLoggingIn =
        state.phase == BiometricLoginPhase.authenticating ||
        state.phase == BiometricLoginPhase.awaitingDeviceVerification;
    _operation++;
    unawaited(_auth.stopAuthentication());
    if (wasLoggingIn) ref.read(loginFlowProvider.notifier).cancel();
    state = _settled(state, clearMessage: true);
  }

  Future<void> _clear(int token) async {
    // Even a partial deletion leaves biometric use off for this process.
    await _storage.clearEnrollment();
    if (_disposed) return;
    final unavailable = state.presentation == null;
    state = BiometricLoginState(
      phase: unavailable
          ? BiometricLoginPhase.unavailable
          : BiometricLoginPhase.disabled,
      presentation: state.presentation,
    );
    if (token == _operation) _operation++;
  }

  int _begin(BiometricLoginPhase phase) {
    state = state.copyWith(phase: phase, clearMessage: true);
    return ++_operation;
  }

  bool _isCurrent(int token) => !_disposed && token == _operation;

  BiometricOperationResult _end(
    BiometricLoginState next,
    BiometricOperationResult result,
  ) {
    state = next;
    _operation++;
    return result;
  }

  BiometricOperationResult _restore(BiometricOperationResult result) => _end(
    _settled(state, message: result.cancelled ? null : result.message),
    result,
  );

  BiometricLoginState _settled(
    BiometricLoginState from, {
    String? message,
    bool clearMessage = false,
  }) => BiometricLoginState(
    phase: from.profile != null
        ? BiometricLoginPhase.enabled
        : from.presentation != null
        ? BiometricLoginPhase.disabled
        : BiometricLoginPhase.unavailable,
    profile: from.profile,
    presentation: from.presentation,
    message: clearMessage ? null : message,
  );

  BiometricOperationResult _fail(String message) {
    if (!state.isBusy) state = state.copyWith(message: message);
    return BiometricOperationResult(succeeded: false, message: message);
  }

  static const _busy = BiometricOperationResult(
    succeeded: false,
    message: 'Please wait for the current request to finish.',
  );

  static BiometricOperationResult _resultFor(BiometricAuthOutcome outcome) =>
      switch (outcome) {
        BiometricAuthOutcome.success => const BiometricOperationResult(
          succeeded: true,
        ),
        BiometricAuthOutcome.cancelled =>
          const BiometricOperationResult.cancelled(),
        BiometricAuthOutcome.temporaryLockout => const BiometricOperationResult(
          succeeded: false,
          message: 'Too many attempts. Try again shortly or use your password.',
        ),
        BiometricAuthOutcome.permanentLockout => const BiometricOperationResult(
          succeeded: false,
          message:
              'Biometrics are locked on this device. Unlock your device, or '
              'use your password.',
        ),
        BiometricAuthOutcome.notEnrolled ||
        BiometricAuthOutcome.unavailable ||
        BiometricAuthOutcome.unsupported => const BiometricOperationResult(
          succeeded: false,
          message: 'Biometrics are not available right now. Use your password.',
        ),
        BiometricAuthOutcome.failure => const BiometricOperationResult(
          succeeded: false,
          message: 'Biometric check failed. Try again or use your password.',
        ),
      };

  /// Login failures are already shown by the login flow's own state.
  static BiometricOperationResult _resultForLogin(LoginAttemptResult result) =>
      switch (result.outcome) {
        LoginAttemptOutcome.completed => const BiometricOperationResult(
          succeeded: true,
        ),
        LoginAttemptOutcome.cancelled =>
          const BiometricOperationResult.cancelled(),
        _ => const BiometricOperationResult(succeeded: false),
      };
}
