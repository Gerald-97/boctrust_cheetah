import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/app_open_recency.dart';
import '../../../helper/biometric_auth_service.dart';
import '../../../helper/biometric_transfer_storage.dart';
import '../../../utils/auth_input.dart';
import '../../account/provider/user_providers.dart';
import '../../onboarding/model/auth_requests.dart';
import '../../onboarding/model/remembered_biometric_profile.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../../onboarding/provider/biometric_login_provider.dart'
    show BiometricOperationResult;
import '../../onboarding/service/auth_service.dart';
import '../model/bill_models.dart';
import '../model/core_submission_models.dart';
import 'core_payments_providers.dart';
import 'core_transfer_attempt_provider.dart';

export '../../onboarding/provider/biometric_login_provider.dart'
    show BiometricOperationResult;

enum BiometricApprovalPhase {
  hydrating,
  ready,
  verifyingPin,
  confirmingBiometric,
  enabling,
  approving,
  clearing,
}

/// What a biometric approval did. Never carries the PIN.
enum ApprovalResult {
  /// The saved PIN was accepted.
  passed,

  /// Nothing was sent; the customer can try the biometric prompt again.
  cancelled,

  /// Nothing was sent and biometric approval cannot be used right now; the
  /// customer enters the PIN instead.
  unavailable,

  /// The saved PIN was rejected and erased; enter the PIN instead.
  wiped,

  /// The attempt or payment ended; its own state says why.
  stopped,
}

/// Biometric transfer approval state. Never holds the PIN.
class BiometricApprovalState {
  const BiometricApprovalState({
    required this.phase,
    this.enabled = false,
    this.presentation,
    this.message,
  });

  final BiometricApprovalPhase phase;

  /// Whether this device holds a valid enrollment for the signed-in customer.
  final bool enabled;

  /// How the device biometric is presented; null while biometrics are not
  /// usable (or not yet checked).
  final BiometricPresentation? presentation;
  final String? message;

  bool get isAvailable => presentation != null;

  bool get isBusy => switch (phase) {
    BiometricApprovalPhase.hydrating || BiometricApprovalPhase.ready => false,
    _ => true,
  };

  BiometricApprovalState copyWith({
    BiometricApprovalPhase? phase,
    bool? enabled,
    String? message,
    bool clearMessage = false,
  }) => BiometricApprovalState(
    phase: phase ?? this.phase,
    enabled: enabled ?? this.enabled,
    presentation: presentation,
    message: clearMessage ? null : message ?? this.message,
  );
}

final biometricApprovalProvider =
    NotifierProvider<BiometricApprovalNotifier, BiometricApprovalState>(
      BiometricApprovalNotifier.new,
    );

/// Approves transfers and bill payments with the transaction PIN saved by
/// the Security Center toggle. The PIN is read into a local only after a
/// successful biometric prompt, passed straight to Core, and dropped.
class BiometricApprovalNotifier extends Notifier<BiometricApprovalState> {
  /// Attempt rejections that mean the PIN request was sent and failed.
  static const _failedPinRequest = {
    CoreRejection.validation,
    CoreRejection.checkRefused,
    CoreRejection.initiationFailed,
    CoreRejection.checkInterrupted,
  };

  int _operation = 0;
  bool _disposed = false;
  Future<void>? _hydration;

  BiometricTransferStorage get _storage =>
      ref.read(biometricTransferStorageProvider);
  BiometricAuthService get _auth => ref.read(biometricAuthServiceProvider);
  AppOpenRecency get _recency => ref.read(appOpenRecencyProvider);

  @override
  BiometricApprovalState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _operation++;
    });
    ref.listen(authSessionProvider, (previous, next) {
      if (previous?.userId == next?.userId) return;
      // Sign-out keeps a same-account enrollment; a different customer's is
      // cleared by the hydrate.
      _cancelActiveOperation();
      unawaited(hydrate());
    });
    Future.microtask(hydrate);
    return const BiometricApprovalState(
      phase: BiometricApprovalPhase.hydrating,
    );
  }

  /// Loads capability and enrollment once the latest app open has been
  /// checked for recency. Concurrent callers share one load.
  Future<void> hydrate() =>
      _hydration ??= _hydrate().whenComplete(() => _hydration = null);

  Future<void> _hydrate() async {
    if (_disposed || state.isBusy) return;
    final token = _operation;
    await _recency.latest();
    final capability = await _auth.checkCapability();
    var enrolled = _recency.biometricsBlocked
        ? null
        : await _storage.loadValidEnrollment();
    if (!_isCurrent(token) || state.isBusy) return;
    final userId = ref.read(authSessionProvider)?.userId;
    if (enrolled != null && userId != null && enrolled != userId) {
      await _storage.clearEnrollment();
      enrolled = null;
      if (!_isCurrent(token)) return;
    }
    if (!capability.supported) {
      // Biometrics were removed from the device: the enrollment is unusable.
      if (enrolled != null) await _storage.clearEnrollment();
      if (!_isCurrent(token)) return;
      state = BiometricApprovalState(
        phase: BiometricApprovalPhase.ready,
        message: capability.reason,
      );
      return;
    }
    state = BiometricApprovalState(
      phase: BiometricApprovalPhase.ready,
      enabled: enrolled != null && enrolled == userId,
      presentation: capability.presentation,
    );
  }

  /// Called when an app open invalidated biometrics: abandons any prompt in
  /// flight so its late result is dropped, then reloads.
  Future<void> revokeForRecency() async {
    if (_disposed) return;
    _cancelActiveOperation();
    await hydrate();
  }

  /// The single cleanup entry for every erase event: stops any prompt in
  /// flight, drops late results, and deletes the saved PIN. Biometric
  /// approval stays off for this process even if a deletion fails.
  Future<void> wipe() async {
    if (_disposed) return;
    _operation++;
    unawaited(_auth.stopAuthentication());
    await _erase();
  }

  /// Turns biometric approval on: verifies [currentPin] with the server,
  /// confirms with a biometric prompt, then saves it for the session's user.
  Future<BiometricOperationResult> enable(String currentPin) async {
    if (state.isBusy) return _busy;
    final session = ref.read(authSessionProvider);
    final profile = ref.read(userProfileProvider).data;
    if (session == null ||
        profile == null ||
        profile.userId != session.userId) {
      return _fail(
        'Your profile is still loading. Please try again in a moment.',
      );
    }
    if (profile.isCreatedPin != true) {
      return _fail('Create a transaction PIN first.');
    }
    if (!isValidTransactionPin(currentPin)) {
      return _fail('Enter your 4-digit transaction PIN.');
    }

    final token = _begin(BiometricApprovalPhase.verifyingPin);
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    final presentation = capability.presentation;
    if (!capability.supported || presentation == null) {
      return _end(
        BiometricApprovalState(
          phase: BiometricApprovalPhase.ready,
          message: capability.reason,
        ),
        BiometricOperationResult(succeeded: false, message: capability.reason),
      );
    }

    final verified = await ref
        .read(authServiceProvider)
        .verifyCurrentPin(VerifyCurrentPinRequest(currentPin));
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (!verified.isDone) {
      final message = verified.noAuth || verified.statusCode == 401
          ? 'That PIN is incorrect.'
          : verified.message ?? 'We could not confirm your PIN.';
      return _restore(
        BiometricOperationResult(succeeded: false, message: message),
      );
    }

    state = state.copyWith(phase: BiometricApprovalPhase.confirmingBiometric);
    final outcome = await _auth.authenticate(
      reason: 'Confirm to approve transfers with biometrics for BOCTRUST',
    );
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (outcome != BiometricAuthOutcome.success) {
      return _restore(_resultFor(outcome));
    }
    // The session may have changed customer during the prompt.
    if (ref.read(authSessionProvider)?.userId != session.userId) {
      return _restore(const BiometricOperationResult.cancelled());
    }

    state = state.copyWith(phase: BiometricApprovalPhase.enabling);
    try {
      await _storage.enable(userId: session.userId, pin: currentPin);
    } on BiometricStorageException catch (error) {
      if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
      return _end(
        BiometricApprovalState(
          phase: BiometricApprovalPhase.ready,
          presentation: presentation,
          message: error.message,
        ),
        BiometricOperationResult(succeeded: false, message: error.message),
      );
    }
    if (!_isCurrent(token)) {
      // Cancelled while saving: never leave a PIN the toggle does not show.
      await _storage.clearEnrollment();
      return const BiometricOperationResult.cancelled();
    }
    return _end(
      BiometricApprovalState(
        phase: BiometricApprovalPhase.ready,
        enabled: true,
        presentation: presentation,
      ),
      const BiometricOperationResult(succeeded: true),
    );
  }

  /// Turns biometric approval off. Confirms with biometrics when the device
  /// can; otherwise the signed-in session authorizes it.
  Future<BiometricOperationResult> disable() async {
    if (state.isBusy) return _busy;
    final token = _begin(BiometricApprovalPhase.confirmingBiometric);
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
    if (capability.supported) {
      final outcome = await _auth.authenticate(
        reason: 'Confirm to turn off biometric approval for BOCTRUST',
      );
      if (!_isCurrent(token)) return const BiometricOperationResult.cancelled();
      if (outcome != BiometricAuthOutcome.success) {
        return _restore(_resultFor(outcome));
      }
    }
    _operation++;
    await _erase();
    return const BiometricOperationResult(succeeded: true);
  }

  /// Approves the transfer attempt [attemptId], which must be waiting for its
  /// PIN, by sending the saved PIN to Core's PIN verification.
  Future<ApprovalResult> approve(int attemptId) async {
    final gate = await _authorize(
      canSend: () => _awaitsPin(attemptId),
      reason: 'Approve this transfer',
    );
    if (gate.result != null) return gate.result!;
    final (token, pin) = (gate.token, gate.pin!);
    if (!_awaitsPin(attemptId)) return _finish(token, ApprovalResult.stopped);
    final step = await ref
        .read(coreTransferAttemptProvider.notifier)
        .verifyPin(attemptId, pin);
    switch (step) {
      case CheckPassed():
        return _finish(token, ApprovalResult.passed);
      case CheckRetry():
        await _erase();
        return ApprovalResult.wiped;
      case CheckStopped():
        final attempt = ref.read(coreTransferAttemptProvider).current;
        final sentAndFailed =
            attempt?.id == attemptId &&
            attempt?.phase == CoreTransferPhase.settled &&
            switch (attempt?.outcome) {
              RejectedSubmission(:final reason) => _failedPinRequest.contains(
                reason,
              ),
              _ => false,
            };
        if (sentAndFailed) await _erase();
        return _finish(token, ApprovalResult.stopped);
    }
  }

  /// Pays [draft] with the saved PIN in Core's single bill payment request.
  Future<ApprovalResult> approveBill(BillPaymentDraft draft) async {
    final gate = await _authorize(
      canSend: () => _canSubmitBill(draft),
      reason: 'Confirm this payment',
    );
    if (gate.result != null) return gate.result!;
    final (token, pin) = (gate.token, gate.pin!);
    if (!_canSubmitBill(draft)) return _finish(token, ApprovalResult.stopped);
    final payments = ref.read(billPaymentProvider.notifier);
    await payments.submit(draft, transactionPin: pin);
    final settled = ref.read(billPaymentProvider);
    if (payments.lastSendBlocked || settled.draft != draft) {
      // Blocked, or dropped when the session ended: nothing was judged.
      return _finish(token, ApprovalResult.stopped);
    }
    switch (settled.outcome) {
      case AcceptedSubmission():
        return _finish(token, ApprovalResult.passed);
      case RejectedSubmission(reason: CoreRejection.insufficientFunds):
        return _finish(token, ApprovalResult.stopped);
      case RejectedSubmission():
        await _erase();
        return ApprovalResult.wiped;
      case UnknownSubmission():
        await _erase();
        return ApprovalResult.stopped;
      case null:
        return _finish(token, ApprovalResult.stopped);
    }
  }

  /// Checks every precondition, prompts, and reads the saved PIN. Returns a
  /// result instead of a PIN when nothing may be sent.
  Future<({int token, String? pin, ApprovalResult? result})> _authorize({
    required bool Function() canSend,
    required String reason,
  }) async {
    ({int token, String? pin, ApprovalResult? result}) stop(
      ApprovalResult result,
    ) => (token: _operation, pin: null, result: result);

    if (_disposed || state.isBusy) return stop(ApprovalResult.cancelled);
    final userId = ref.read(authSessionProvider)?.userId;
    if (userId == null || !_inForeground) {
      return stop(ApprovalResult.cancelled);
    }
    if (!canSend()) return stop(ApprovalResult.stopped);

    final token = _begin(BiometricApprovalPhase.approving);
    ({int token, String? pin, ApprovalResult? result}) end(
      ApprovalResult result,
    ) => (token: token, pin: null, result: _finish(token, result));

    await _recency.latest();
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    if (_recency.biometricsBlocked) return end(ApprovalResult.unavailable);
    final enrolled = await _storage.loadValidEnrollment();
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    if (enrolled != userId) {
      if (enrolled != null) await _storage.clearEnrollment();
      if (_isCurrent(token)) state = state.copyWith(enabled: false);
      return end(ApprovalResult.unavailable);
    }
    final capability = await _auth.checkCapability();
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    if (!capability.supported) {
      // Biometrics were removed or the hardware is no longer usable.
      await _erase(message: capability.reason, unavailable: true);
      return end(ApprovalResult.unavailable);
    }

    final outcome = await _auth.authenticate(reason: reason);
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    switch (outcome) {
      case BiometricAuthOutcome.success:
        break;
      case BiometricAuthOutcome.cancelled:
        return end(ApprovalResult.cancelled);
      case BiometricAuthOutcome.failure:
        state = state.copyWith(message: _resultFor(outcome).message);
        return end(ApprovalResult.cancelled);
      case BiometricAuthOutcome.notEnrolled:
        await _erase(message: _resultFor(outcome).message);
        return end(ApprovalResult.unavailable);
      case BiometricAuthOutcome.temporaryLockout ||
          BiometricAuthOutcome.permanentLockout ||
          BiometricAuthOutcome.unavailable ||
          BiometricAuthOutcome.unsupported:
        state = state.copyWith(message: _resultFor(outcome).message);
        return end(ApprovalResult.unavailable);
    }

    // An app open or sign-out during the prompt may have invalidated it.
    await _recency.latest();
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    if (_recency.biometricsBlocked) return end(ApprovalResult.unavailable);
    if (ref.read(authSessionProvider)?.userId != userId || !_inForeground) {
      return end(ApprovalResult.cancelled);
    }
    final pin = await _storage.readPinAfterAuthentication(userId);
    if (!_isCurrent(token)) return end(ApprovalResult.cancelled);
    if (pin == null) {
      // Unreadable or mismatched: the storage already cleared it.
      state = state.copyWith(enabled: false);
      return end(ApprovalResult.unavailable);
    }
    return (token: token, pin: pin, result: null);
  }

  bool get _inForeground =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool _awaitsPin(int attemptId) {
    final current = ref.read(coreTransferAttemptProvider).current;
    return current?.id == attemptId &&
        current?.phase == CoreTransferPhase.awaitingPin;
  }

  /// Mirrors [CoreSubmissionNotifier.submit]'s guards, so a call that would
  /// send nothing is never mistaken for a judged request.
  bool _canSubmitBill(BillPaymentDraft draft) {
    final current = ref.read(billPaymentProvider);
    if (current.inFlight) return false;
    final settled = current.outcome;
    return current.draft != draft ||
        (settled is! AcceptedSubmission && settled is! UnknownSubmission);
  }

  /// Settles a finished approval when it is still the current operation.
  ApprovalResult _finish(int token, ApprovalResult result) {
    if (_isCurrent(token)) {
      state = state.copyWith(phase: BiometricApprovalPhase.ready);
      _operation++;
    }
    return result;
  }

  void _cancelActiveOperation() {
    if (!state.isBusy || state.phase == BiometricApprovalPhase.clearing) {
      return;
    }
    _operation++;
    unawaited(_auth.stopAuthentication());
    state = state.copyWith(
      phase: BiometricApprovalPhase.ready,
      clearMessage: true,
    );
  }

  /// Deletes the enrollment and shows approval off, whatever the deletion
  /// result. Late results of the operation that called it are dropped.
  Future<void> _erase({String? message, bool unavailable = false}) async {
    if (!_disposed) {
      state = state.copyWith(
        phase: BiometricApprovalPhase.clearing,
        enabled: false,
      );
    }
    await _storage.clearEnrollment();
    if (_disposed) return;
    _operation++;
    state = BiometricApprovalState(
      phase: BiometricApprovalPhase.ready,
      presentation: unavailable ? null : state.presentation,
      message: message,
    );
  }

  int _begin(BiometricApprovalPhase phase) {
    state = state.copyWith(phase: phase, clearMessage: true);
    return ++_operation;
  }

  bool _isCurrent(int token) => !_disposed && token == _operation;

  BiometricOperationResult _end(
    BiometricApprovalState next,
    BiometricOperationResult result,
  ) {
    state = next;
    _operation++;
    return result;
  }

  BiometricOperationResult _restore(BiometricOperationResult result) => _end(
    BiometricApprovalState(
      phase: BiometricApprovalPhase.ready,
      enabled: state.enabled,
      presentation: state.presentation,
      message: result.cancelled ? null : result.message,
    ),
    result,
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
          message: 'Too many attempts. Try again shortly or use your PIN.',
        ),
        BiometricAuthOutcome.permanentLockout => const BiometricOperationResult(
          succeeded: false,
          message:
              'Biometrics are locked on this device. Unlock your device, or '
              'use your PIN.',
        ),
        BiometricAuthOutcome.notEnrolled ||
        BiometricAuthOutcome.unavailable ||
        BiometricAuthOutcome.unsupported => const BiometricOperationResult(
          succeeded: false,
          message: 'Biometrics are not available right now. Use your PIN.',
        ),
        BiometricAuthOutcome.failure => const BiometricOperationResult(
          succeeded: false,
          message: 'Biometric check failed. Try again or use your PIN.',
        ),
      };
}
