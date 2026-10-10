import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_check_progress.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_initiation.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';

final coreTransferServiceProvider = Provider<CoreTransferService>(
  (ref) => CoreTransferService(ref.watch(coreApiServiceProvider)),
);

/// The documented single-transfer ceiling, ₦25,000,000, in Kobo.
const kMaxTransferKobo = '2500000000';

/// Core customer transfers: recipient lookups, the staged initiate → OTP →
/// finalize flow, and live status of a transfer already sent.
///
/// Every POST is sent once and never retried. Only finalize moves money and
/// it carries no body; the PIN and OTP go to their own verify routes and are
/// never kept. Requests are logged in full on staging (product decision);
/// only the name enquiry is redacted, as Core can return a BVN.
class CoreTransferService {
  const CoreTransferService(this._api);
  final ApiService? _api;

  static const _readUnavailable = 'Transfers are not available right now.';

  static Map<String, Object?> _logAs(String template) => {
    LoggingInterceptor.privacySensitivePathKey: template,
  };

  /// Records a pending BOCTRUST transfer. No money moves.
  Future<NotifierState<CoreTransferInitiation>> initiateBoctrust(
    BoctrustTransferDraft draft,
  ) => _initiate(
    CoreApiEndpoints.intrabankTransferInitiate,
    draft.amountKobo,
    draft.toJson(),
  );

  /// Records a pending transfer to another bank. No money moves.
  Future<NotifierState<CoreTransferInitiation>> initiateInterbank(
    InterbankTransferDraft draft,
  ) => _initiate(
    CoreApiEndpoints.interbankTransferInitiate,
    draft.amountKobo,
    draft.toJson(),
  );

  Future<NotifierState<CoreTransferInitiation>> _initiate(
    String path,
    String amountKobo,
    Map<String, Object?> body,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    final kobo = BigInt.tryParse(amountKobo);
    if (kobo == null || kobo <= BigInt.zero) {
      return const NotifierState.error('Enter a valid amount.');
    }
    if (kobo > BigInt.parse(kMaxTransferKobo)) {
      return const NotifierState.error(
        'The most you can send at once is ₦25,000,000.',
      );
    }
    return NotifierState.fromResponse(
      await api.postData<CoreTransferInitiation>(
        path,
        data: body,
        parser: CoreTransferInitiation.fromJson,
      ),
    );
  }

  /// Whether a check or finalize for [initiation] may be sent at all: a
  /// liveness check or an expired initiation is refused locally.
  static bool _sendable(CoreTransferInitiation initiation) =>
      initiation.supported && !initiation.isExpiredAt(DateTime.now());

  Future<NotifierState<CoreCheckProgress>> _check(
    String path, {
    Object? body,
  }) async => NotifierState.fromResponse(
    await _api!.postData<CoreCheckProgress>(
      path,
      data: body,
      parser: CoreCheckProgress.fromJson,
    ),
  );

  /// Verifies the transaction PIN; Core sends the OTP when one is required.
  /// The PIN goes only in this request's body and is never kept.
  Future<NotifierState<CoreCheckProgress>> verifyTransferPin(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String pin,
  ) async {
    if (_api == null || !_sendable(initiation)) {
      return const NotifierState.blocked(_readUnavailable);
    }
    return _check(
      switch (kind) {
        CoreTransferKind.intrabank =>
          CoreApiEndpoints.intrabankTransferPinVerify(initiation.reference),
        CoreTransferKind.interbank =>
          CoreApiEndpoints.interbankTransferPinVerify(initiation.reference),
      },
      body: {'transactionPin': pin},
    );
  }

  /// Asks Core to send the OTP again. Only after the PIN was verified, and
  /// only on the customer's request.
  Future<NotifierState<CoreCheckProgress>> resendTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    if (_api == null || !_sendable(initiation)) {
      return const NotifierState.blocked(_readUnavailable);
    }
    return _check(switch (kind) {
      CoreTransferKind.intrabank => CoreApiEndpoints.intrabankTransferOtpResend(
        initiation.reference,
      ),
      CoreTransferKind.interbank => CoreApiEndpoints.interbankTransferOtpResend(
        initiation.reference,
      ),
    });
  }

  /// Verifies the OTP the customer typed. It goes only in this request's
  /// body and is never kept.
  Future<NotifierState<CoreCheckProgress>> verifyTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String otp,
  ) async {
    if (_api == null || !_sendable(initiation)) {
      return const NotifierState.blocked(_readUnavailable);
    }
    return _check(
      switch (kind) {
        CoreTransferKind.intrabank =>
          CoreApiEndpoints.intrabankTransferOtpVerify(initiation.reference),
        CoreTransferKind.interbank =>
          CoreApiEndpoints.interbankTransferOtpVerify(initiation.reference),
      },
      body: {'otpCode': otp},
    );
  }

  /// Moves the money once every required check passed. No body: credentials
  /// went to the verify routes. Sent once; classify the reply with
  /// `mapCoreTransferSubmission`.
  Future<ServiceResponse<CoreTransferAck>> finalizeTransfer(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    final api = _api;
    if (api == null || !_sendable(initiation)) {
      return const ServiceResponse.blocked(_readUnavailable);
    }
    return api.postData<CoreTransferAck>(switch (kind) {
      CoreTransferKind.intrabank => CoreApiEndpoints.intrabankTransferFinalize(
        initiation.reference,
      ),
      CoreTransferKind.interbank => CoreApiEndpoints.interbankTransferFinalize(
        initiation.reference,
      ),
    }, parser: CoreTransferAck.fromJson);
  }

  Future<NotifierState<List<CommercialBank>>> getBanks() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    return NotifierState.fromResponse(
      await api.getData<List<CommercialBank>>(
        CoreApiEndpoints.interbankBanks,
        parser: CommercialBank.listFromJson,
      ),
    );
  }

  /// The account name at [bankCode]; only ten-digit numbers are sent.
  Future<NotifierState<NameEnquiryResult>> nameEnquiry({
    required String bankCode,
    required String accountNumber,
    CancelToken? cancelToken,
  }) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    if (!RegExp(r'^\d{10}$').hasMatch(accountNumber)) {
      return const NotifierState.error('Enter a 10-digit account number.');
    }
    return NotifierState.fromResponse(
      await api.postData<NameEnquiryResult>(
        CoreApiEndpoints.interbankNameEnquiry,
        data: {'accountNumber': accountNumber, 'bankCode': bankCode},
        parser: NameEnquiryResult.fromJson,
        // Core can return the recipient's BVN; keep the bodies out of logs.
        requestExtra: _logAs(CoreApiEndpoints.interbankNameEnquiry),
        cancelToken: cancelToken,
      ),
    );
  }

  /// A read only; never resends the transfer.
  Future<NotifierState<InterbankTransferStatus>> getTransferStatus(
    String reference,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    return NotifierState.fromResponse(
      await api.getData<InterbankTransferStatus>(
        CoreApiEndpoints.interbankTransferStatus(reference),
        parser: InterbankTransferStatus.fromJson,
      ),
    );
  }

  /// BankOne's live status for a tracked transfer. A bodyless read; it never
  /// resends, retries or reverses the transfer. A malformed reference is
  /// refused before any request.
  Future<NotifierState<CoreLiveTransferStatus>> requeryTransfer(
    CoreTrackingReference tracking,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    if (!tracking.isWellFormed) {
      return const NotifierState.error(
        "This transfer can't be checked right now.",
      );
    }
    final (path, template) = switch (tracking.kind) {
      CoreTransferKind.intrabank => (
        CoreApiEndpoints.intrabankTransferRequery(tracking.value),
        CoreApiEndpoints.intrabankTransferRequeryTemplate,
      ),
      CoreTransferKind.interbank => (
        CoreApiEndpoints.interbankTransferRequery(tracking.value),
        CoreApiEndpoints.interbankTransferRequeryTemplate,
      ),
    };
    return NotifierState.fromResponse(
      await api.postData<CoreLiveTransferStatus>(
        path,
        parser: (json) => CoreLiveTransferStatus.fromJson(tracking.kind, json),
      ),
    );
  }
}
