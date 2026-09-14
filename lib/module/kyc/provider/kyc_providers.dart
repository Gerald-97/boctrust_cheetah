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

  /// Starts (or resumes) identity verification.
  ///
  /// Returns the initiation to launch capture with, or null when capture
  /// cannot be opened. Mirrors the government-ID notifier.
  Future<KycInitiationData?> submit({
    required IdentityType identityType,
    required String identityNumber,
  }) async {
    // Idempotency is not documented for initiation, so duplicate submission is
    // prevented client-side while a request is outstanding.
    if (_inFlight) return null;

    final number = identityNumber.trim();
    if (!isValidIdentityNumber(number)) {
      state = NotifierState.error(
        'Enter your $kIdentityNumberLength-digit ${identityType.label}.',
        data: state.data,
      );
      return null;
    }

    final previous = state.data ?? const KycFlowData();

    // A cached job reopens capture directly; re-initiating would earn a 409.
    final cached = previous.initiation;
    // BVN is re-entered on every pending retry so the backend can authorize
    // the number against the current account. Reusing a cached BVN job could
    // silently bind a different number to the old Smile job. NIN retains the
    // original in-process resume behavior.
    if (identityType != IdentityType.bvn &&
        cached != null &&
        cached.identityType == identityType.wireValue) {
      state = NotifierState.done(
        previous.copyWith(stage: KycFlowStage.awaitingProvider),
      );
      return cached;
    }

    _inFlight = true;
    final token = beginRequest();
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
      if (!isCurrent(token)) return null;

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
        return data;
      }

      // 409 means a verification is already running. That is a resumable
      // state, not a failure: keep whatever context we already hold. Same
      // three-case rule as the government-ID flow.
      if (result.statusCode == 409) {
        // A 409 has more than one meaning and the backend sends the same
        // `CONFLICT` code for all of them: a verification already running on
        // this account, or an identity number already bound to a different
        // account. Only the first is resumable, and only the server's message
        // can tell them apart, so never assert a cause of our own.
        final resumable = identityType == IdentityType.bvn
            ? null
            : previous.initiation ??
                  GovernmentIdVerificationNotifier._resumableFrom(data);

        if (resumable != null) {
          state = NotifierState.done(
            previous.copyWith(
              stage: KycFlowStage.awaitingProvider,
              initiation: resumable,
            ),
            message: result.message ?? 'Verification already in progress.',
            statusCode: result.statusCode,
            meta: result.meta,
          );
          await _refreshAuthoritativeState();
          return resumable;
        }

        // Nothing can reopen capture from here, so this is a failure to start
        // rather than progress. Surfacing it as done previously rendered the
        // server's rejection in a success style.
        state = NotifierState.error(
          result.message ?? 'We could not start your verification.',
          data: previous.copyWith(stage: KycFlowStage.failed),
          statusCode: result.statusCode,
          errorCode: result.errorCode,
          errors: result.errors,
          meta: result.meta,
        );
        await _refreshAuthoritativeState();
        return null;
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
      return null;
    } finally {
      if (isCurrent(token)) _inFlight = false;
    }
  }

  void markPendingReview() => _setStage(KycFlowStage.pendingReview);

  void markAwaitingProvider() => _setStage(KycFlowStage.awaitingProvider);

  /// Keeps the cached initiation so a native SDK error stays retryable against
  /// the same job rather than forcing a 409 on the next attempt.
  void markProviderFailure() => _setStage(KycFlowStage.failed);

  void markReconciling() => _setStage(KycFlowStage.reconciling);

  void _setStage(KycFlowStage stage) {
    final previous = state.data ?? const KycFlowData();
    state = NotifierState.done(previous.copyWith(stage: stage));
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
    beginRequest();
    _inFlight = false;
    state = const NotifierState.idle(data: KycFlowData());
  }

  /// Cancels a client-side request when the user leaves the identity screen.
  /// Any server job remains resumable; this only prevents a late response from
  /// blocking or overwriting a later attempt.
  void cancelPendingRequest() {
    beginRequest();
    _inFlight = false;
    final previous = state.data ?? const KycFlowData();
    if (state.isLoading) {
      state = NotifierState.idle(
        data: previous.copyWith(
          stage: previous.initiation == null
              ? KycFlowStage.idle
              : KycFlowStage.awaitingProvider,
        ),
      );
    }
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

  /// Starts (or resumes) a government-ID verification.
  ///
  /// Returns the initiation to launch capture with, or null when capture cannot
  /// be opened. Null is not necessarily an error: a 409 with no recoverable job
  /// context leaves an existing verification in progress.
  Future<KycInitiationData?> submit({
    required GovernmentIdDocumentType documentType,
    String? documentNumber,
  }) async {
    if (_inFlight) return null;

    final previous = state.data ?? const KycFlowData();

    // Case 1: this process still holds the job the user backed out of. Reopen
    // capture against it directly. Initiating again would only earn a 409, so
    // the request is skipped rather than made and recovered from.
    final cached = previous.initiation;
    if (cached != null && cached.documentType == documentType.wireValue) {
      state = NotifierState.done(
        previous.copyWith(stage: KycFlowStage.awaitingProvider),
      );
      return cached;
    }

    _inFlight = true;
    final token = beginRequest();
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
      if (!isCurrent(token)) return null;

      final data = result.data;
      if (result.isDone && data != null) {
        state = NotifierState.done(
          previous.fromInitiation(data, KycFlowStage.awaitingProvider),
          message: result.message,
          statusCode: result.statusCode,
          meta: result.meta,
        );
        // Initiation creates a job; it cannot change verification state, so the
        // full four-provider refresh is deliberately not run here.
        await ref.read(userTierProvider.notifier).load();
        return data;
      }

      if (result.statusCode == 409) {
        // A verification is already running server-side. Re-initiating would
        // orphan it, so capture may only reopen against the existing job.
        //
        // 1. The cached initiation, if this process still holds it. This is the
        //    ordinary cancel-and-retry case.
        // 2. Otherwise the 409 body, if the backend returned the job context.
        // 3. Otherwise nothing can reopen capture. See the named backend
        //    blocker in the plan: after a process restart this is currently the
        //    only reachable outcome, and it stays blocked until the job expires
        //    or its webhook fails.
        final resumable = previous.initiation ?? _resumableFrom(data);

        if (resumable != null) {
          state = NotifierState.done(
            previous.copyWith(
              stage: KycFlowStage.awaitingProvider,
              initiation: resumable,
            ),
            message: result.message ?? 'Verification already in progress.',
            statusCode: result.statusCode,
            meta: result.meta,
          );
          return resumable;
        }

        // Case 3: a failure to start, not progress. The server's message is
        // the only thing that explains which conflict this was.
        state = NotifierState.error(
          result.message ?? 'We could not start your verification.',
          data: previous.copyWith(stage: KycFlowStage.failed),
          statusCode: result.statusCode,
          errorCode: result.errorCode,
          errors: result.errors,
          meta: result.meta,
        );
        return null;
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
      return null;
    } finally {
      _inFlight = false;
    }
  }

  /// A 409 body is only resumable if it names the job capture must reopen.
  static KycInitiationData? _resumableFrom(KycInitiationData? data) {
    if (data == null) return null;
    final hasJobContext =
        (data.smileUserId?.trim().isNotEmpty ?? false) &&
        (data.smileJobId?.trim().isNotEmpty ?? false) &&
        (data.callbackUrl?.trim().isNotEmpty ?? false);
    return hasJobContext ? data : null;
  }

  void markPendingReview() => _setStage(KycFlowStage.pendingReview);

  void markAwaitingProvider() => _setStage(KycFlowStage.awaitingProvider);

  /// Keeps the cached initiation so a native SDK error stays retryable against
  /// the same job rather than forcing a 409 on the next attempt.
  void markProviderFailure() => _setStage(KycFlowStage.failed);

  void markReconciling() => _setStage(KycFlowStage.reconciling);

  void _setStage(KycFlowStage stage) {
    final previous = state.data ?? const KycFlowData();
    state = NotifierState.done(previous.copyWith(stage: stage));
  }

  void clear() {
    _inFlight = false;
    state = const NotifierState.idle(data: KycFlowData());
  }
}
