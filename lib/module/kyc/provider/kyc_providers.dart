import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../helper/signed_upload_client.dart';
import '../../account/provider/user_providers.dart';
import '../model/kyc_models.dart';
import '../service/kyc_service.dart';
import 'kyc_status_provider.dart';

final identityVerificationProvider =
    NotifierProvider<IdentityVerificationNotifier, NotifierState<KycFlowData>>(
      IdentityVerificationNotifier.new,
    );

/// Drives BVN/NIN initiation.
///
/// A successful initiation moves the flow to [KycFlowStage.awaitingProvider].
/// It never asserts verification success — only refreshed profile/tier data
/// can do that.
class IdentityVerificationNotifier extends Notifier<NotifierState<KycFlowData>>
    with StaleResultGuard<NotifierState<KycFlowData>> {
  @override
  NotifierState<KycFlowData> build() {
    trackDisposal();
    return const NotifierState.idle(data: KycFlowData());
  }

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
    final token = beginRequest();
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
      // A response that lands after the user left, or after a newer
      // submission started, must not overwrite the current flow state.
      if (!isCurrent(token)) return;

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
  ///
  /// Delegates to the shared fan-out so a resume, a manual Refresh, and a
  /// post-submission refresh share one in-flight round of requests.
  Future<void> _refreshAuthoritativeState() =>
      refreshKycAuthoritativeState(ref);

  /// Re-checks status after an app resume or an explicit user refresh.
  Future<void> refreshStatus() => _refreshAuthoritativeState();

  void clear() {
    _inFlight = false;
    state = const NotifierState.idle(data: KycFlowData());
  }
}

final utilityBillUploadProvider =
    NotifierProvider<UtilityBillUploadNotifier, NotifierState<KycFlowData>>(
      UtilityBillUploadNotifier.new,
    );

/// Runs the resumable initiate → signed PUT → complete sequence.
///
/// Completion is never called after a failed or expired upload, and a lapsed
/// signed link is replaced by a fresh initiation rather than retried.
class UtilityBillUploadNotifier extends Notifier<NotifierState<KycFlowData>>
    with StaleResultGuard<NotifierState<KycFlowData>> {
  @override
  NotifierState<KycFlowData> build() {
    trackDisposal();
    return const NotifierState.idle(data: KycFlowData());
  }

  bool _inFlight = false;

  KycFlowData get _flow => state.data ?? const KycFlowData();

  /// Records a picked file after local validation.
  void selectBill(SelectedUtilityBill bill) {
    if (_inFlight) return;
    if (!kUtilityBillContentTypes.contains(bill.contentType)) {
      state = NotifierState.error(
        'Choose a PDF, JPEG, or PNG file.',
        data: _flow,
      );
      return;
    }
    // Checked before any network call so an oversized file never burns a
    // signed upload link.
    if (bill.sizeInBytes > kUtilityBillMaxBytes) {
      state = NotifierState.error(
        'That file is larger than 10 MB. Choose a smaller file.',
        data: _flow,
      );
      return;
    }
    state = NotifierState.done(
      _flow.copyWith(stage: KycFlowStage.selectingFile, selectedBill: bill),
    );
  }

  void clearSelection() {
    if (_inFlight) return;
    state = NotifierState.done(
      KycFlowData(
        stage: KycFlowStage.idle,
        verificationId: _flow.verificationId,
      ),
    );
  }

  /// Executes the full sequence for the currently selected file.
  Future<void> submit({
    required String residentialAddress,
    String? residentialState,
    String? residentialLga,
    String? utilityProvider,
    UtilityType? utilityType,
    String? utilityNumber,
    DateTime? billIssuedAt,
  }) async {
    if (_inFlight) return;

    final flow = _flow;
    final bill = flow.selectedBill;
    if (bill == null) {
      state = NotifierState.error(
        'Choose your utility bill first.',
        data: flow,
      );
      return;
    }
    if (residentialAddress.trim().isEmpty) {
      state = NotifierState.error(
        'Enter your residential address.',
        data: flow,
      );
      return;
    }

    _inFlight = true;
    final token = beginRequest();
    try {
      // Stage 1 — ask the API for a signed upload target.
      state = NotifierState.loading(
        data: flow.copyWith(stage: KycFlowStage.requestingUpload),
      );
      final initiation = await ref
          .read(kycServiceProvider)
          .initiateUtilityBillUpload(
            UtilityBillInitiationRequest(
              residentialAddress: residentialAddress.trim(),
              contentType: bill.contentType,
              residentialState: residentialState,
              residentialLga: residentialLga,
              utilityProvider: utilityProvider,
              utilityType: utilityType,
              utilityNumber: utilityNumber,
              billIssuedAt: billIssuedAt,
              originalFileName: bill.fileName,
              fileSizeBytes: bill.sizeInBytes,
            ),
          );

      // Abandoning here is safe: no bytes have moved yet.
      if (!isCurrent(token)) return;

      final target = initiation.data;
      if (!initiation.isDone || target == null) {
        state = NotifierState.error(
          initiation.message ?? 'We could not start your upload.',
          data: flow.copyWith(stage: KycFlowStage.failed),
          statusCode: initiation.statusCode,
          errorCode: initiation.errorCode,
          errors: initiation.errors,
          meta: initiation.meta,
          noAuth: initiation.noAuth,
        );
        return;
      }

      final withTarget = flow.copyWith(
        stage: KycFlowStage.uploading,
        verificationId: target.verificationId,
        uploadExpiresAt: target.expiresInSeconds == null
            ? null
            : DateTime.now().toUtc().add(
                Duration(seconds: target.expiresInSeconds!),
              ),
      );
      state = NotifierState.loading(data: withTarget);

      // Stage 2 — PUT the bytes through the no-auth upload client.
      final upload = await ref
          .read(signedUploadClientProvider)
          .putBytes(
            url: target.uri,
            bytes: bill.bytes,
            headers: target.headersFor(bill.contentType),
          );

      // The session ended or a newer submission started while bytes were in
      // flight. Stop before completion: confirming an upload for a flow that
      // is no longer the user's would be wrong even if the PUT succeeded.
      if (!isCurrent(token)) return;

      if (!upload.isDone) {
        // Completion must not run for bytes that never landed. Drop the
        // verification context so a retry re-initiates rather than reusing a
        // link that may have lapsed.
        state = NotifierState.error(
          upload.message ?? 'The upload failed. Please try again.',
          data: withTarget
              .copyWith(stage: KycFlowStage.failed)
              .withoutUploadTarget(),
          statusCode: upload.statusCode,
        );
        return;
      }

      // Stage 3 — tell the API the bytes are in place.
      state = NotifierState.loading(
        data: withTarget.copyWith(
          stage: KycFlowStage.completing,
          uploadCompleted: true,
        ),
      );
      await _complete(withTarget.copyWith(uploadCompleted: true), token);
    } finally {
      _inFlight = false;
    }
  }

  /// Retries only the completion POST after a successful upload.
  ///
  /// Re-uploading is unnecessary and would waste a fresh signed link, so this
  /// is offered only while the PUT is known to have succeeded.
  Future<void> retryCompletion() async {
    if (_inFlight) return;
    final flow = _flow;
    if (!flow.uploadCompleted || flow.verificationId == null) return;

    _inFlight = true;
    final token = beginRequest();
    try {
      state = NotifierState.loading(
        data: flow.copyWith(stage: KycFlowStage.completing),
      );
      await _complete(flow, token);
    } finally {
      _inFlight = false;
    }
  }

  Future<void> _complete(KycFlowData flow, int token) async {
    final result = await ref
        .read(kycServiceProvider)
        .completeUtilityBillUpload(flow.verificationId!);
    if (!isCurrent(token)) return;

    final completion = result.data;
    // A completion that does not name the active verification, or that carries
    // no status, is not evidence this user's bill was accepted. Treat it as a
    // failure the user can retry rather than silently showing pending review.
    final confirmsActiveFlow =
        completion != null &&
        completion.verificationId == flow.verificationId &&
        completion.status.trim().isNotEmpty;

    if (result.isDone && confirmsActiveFlow) {
      state = NotifierState.done(
        flow.copyWith(stage: KycFlowStage.pendingReview),
        message: result.message,
        statusCode: result.statusCode,
        meta: result.meta,
      );
      // Pending review is not verified: only the refreshed aggregates can
      // move the tier checklist.
      await refreshKycAuthoritativeState(ref);
      return;
    }

    state = NotifierState.error(
      result.isDone
          ? 'We could not confirm your submission. Please try again.'
          : result.message ?? 'We could not finish your submission.',
      // uploadCompleted stays true so the screen can offer a completion-only
      // retry instead of a full re-upload.
      data: flow.copyWith(stage: KycFlowStage.failed),
      statusCode: result.statusCode,
      errorCode: result.errorCode,
      errors: result.errors,
      meta: result.meta,
      noAuth: result.noAuth,
    );
  }

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
/// Document types are a closed set confirmed by the backend, so the screen can
/// offer them directly.
class GovernmentIdVerificationNotifier
    extends Notifier<NotifierState<KycFlowData>>
    with StaleResultGuard<NotifierState<KycFlowData>> {
  @override
  NotifierState<KycFlowData> build() {
    trackDisposal();
    return const NotifierState.idle(data: KycFlowData());
  }

  bool _inFlight = false;

  Future<void> submit({
    required GovernmentIdDocumentType documentType,
    String? documentNumber,
  }) async {
    if (_inFlight) return;

    _inFlight = true;
    final token = beginRequest();
    final previous = state.data ?? const KycFlowData();
    state = NotifierState.loading(
      data: previous.copyWith(stage: KycFlowStage.initiating),
    );

    try {
      final result = await ref
          .read(kycServiceProvider)
          .initiateGovernmentId(
            GovernmentIdVerificationRequest(
              documentType: documentType,
              documentNumber: documentNumber?.trim(),
            ),
          );
      if (!isCurrent(token)) return;

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
