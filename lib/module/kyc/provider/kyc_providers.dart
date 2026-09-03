import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../account/provider/user_providers.dart';
import '../../home/provider/home_provider.dart';
import '../model/kyc_models.dart';
import '../service/kyc_service.dart';

final identityVerificationProvider =
    NotifierProvider<IdentityVerificationNotifier, NotifierState<KycFlowData>>(
      IdentityVerificationNotifier.new,
    );

/// Drives BVN/NIN initiation.
///
/// A successful initiation moves the flow to [KycFlowStage.awaitingProvider].
/// It never asserts verification success — only refreshed profile/tier data
/// can do that.
class IdentityVerificationNotifier
    extends Notifier<NotifierState<KycFlowData>> {
  @override
  NotifierState<KycFlowData> build() =>
      const NotifierState.idle(data: KycFlowData());

  bool _inFlight = false;

  Future<void> submit({
    required IdentityType identityType,
    required String identityNumber,
  }) async {
    // Idempotency is not documented for initiation, so duplicate submission is
    // prevented client-side while a request is outstanding.
    if (_inFlight) return;

    final number = identityNumber.trim();
    if (!isValidIdentityNumber(number)) {
      state = NotifierState.error(
        'Enter your $kIdentityNumberLength-digit ${identityType.label}.',
        data: state.data,
      );
      return;
    }

    _inFlight = true;
    final previous = state.data ?? const KycFlowData();
    state = NotifierState.loading(
      data: previous.copyWith(stage: KycFlowStage.initiating),
    );

    try {
      final result = await ref
          .read(kycServiceProvider)
          .initiateIdentity(
            IdentityVerificationRequest(
              identityType: identityType,
              identityNumber: number,
            ),
          );

      final data = result.data;
      if (result.isDone && data != null) {
        state = NotifierState.done(
          previous.fromInitiation(data, KycFlowStage.awaitingProvider),
          message: result.message,
          statusCode: result.statusCode,
          meta: result.meta,
        );
        // The backend owns the verdict; pull the authoritative aggregate.
        await _refreshAuthoritativeState();
        return;
      }

      // 409 means a verification is already running. That is a resumable
      // state, not a failure: keep whatever context we already hold.
      if (result.statusCode == 409) {
        state = NotifierState.done(
          previous.copyWith(stage: KycFlowStage.awaitingProvider),
          message: result.message ?? 'Verification already in progress.',
          statusCode: result.statusCode,
          meta: result.meta,
        );
        await _refreshAuthoritativeState();
        return;
      }

      state = NotifierState.error(
        result.message ?? 'We could not start your verification.',
        data: previous.copyWith(stage: KycFlowStage.failed),
        statusCode: result.statusCode,
        errorCode: result.errorCode,
        errors: result.errors,
        meta: result.meta,
        noAuth: result.noAuth,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Reloads the aggregates that actually carry verification status.
  Future<void> _refreshAuthoritativeState() async {
    await Future.wait([
      ref.read(userProfileProvider.notifier).load(),
      ref.read(userTierProvider.notifier).load(),
      ref.read(userHomeProvider.notifier).load(),
    ]);
  }

  /// Re-checks status after an app resume or an explicit user refresh.
  Future<void> refreshStatus() => _refreshAuthoritativeState();

  void clear() {
    _inFlight = false;
    state = const NotifierState.idle(data: KycFlowData());
  }
}

final governmentIdVerificationProvider =
    NotifierProvider<
      GovernmentIdVerificationNotifier,
      NotifierState<KycFlowData>
    >(GovernmentIdVerificationNotifier.new);

/// Drives government-ID initiation.
///
/// The canonical `documentType` wire values are not published, so the screen
/// keeps document selection blocked. This notifier is ready for the moment
/// those values are documented, and accepts only a caller-supplied wire value.
class GovernmentIdVerificationNotifier
    extends Notifier<NotifierState<KycFlowData>> {
  @override
  NotifierState<KycFlowData> build() =>
      const NotifierState.idle(data: KycFlowData());

  bool _inFlight = false;

  Future<void> submit({
    required String documentType,
    String? documentNumber,
  }) async {
    if (_inFlight) return;
    if (documentType.trim().isEmpty) {
      state = NotifierState.error('Select a document type.', data: state.data);
      return;
    }

    _inFlight = true;
    final previous = state.data ?? const KycFlowData();
    state = NotifierState.loading(
      data: previous.copyWith(stage: KycFlowStage.initiating),
    );

    try {
      final result = await ref
          .read(kycServiceProvider)
          .initiateGovernmentId(
            GovernmentIdVerificationRequest(
              documentType: documentType.trim(),
              documentNumber: documentNumber?.trim(),
            ),
          );

      final data = result.data;
      if (result.isDone && data != null) {
        state = NotifierState.done(
          previous.fromInitiation(data, KycFlowStage.awaitingProvider),
          message: result.message,
          statusCode: result.statusCode,
          meta: result.meta,
        );
        await ref.read(userTierProvider.notifier).load();
        return;
      }

      if (result.statusCode == 409) {
        state = NotifierState.done(
          previous.copyWith(stage: KycFlowStage.awaitingProvider),
          message: result.message ?? 'Verification already in progress.',
          statusCode: result.statusCode,
          meta: result.meta,
        );
        return;
      }

      state = NotifierState.error(
        result.message ?? 'We could not start your verification.',
        data: previous.copyWith(stage: KycFlowStage.failed),
        statusCode: result.statusCode,
        errorCode: result.errorCode,
        errors: result.errors,
        meta: result.meta,
        noAuth: result.noAuth,
      );
    } finally {
      _inFlight = false;
    }
  }

  void clear() {
    _inFlight = false;
    state = const NotifierState.idle(data: KycFlowData());
  }
}
