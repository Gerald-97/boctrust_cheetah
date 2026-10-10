import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
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
/// Every POST is sent once and never retried. Only finalize moves money; the
/// PIN and OTP pass straight into its body and are never kept. Requests are
/// logged by path template only, so recipients, references and credentials
/// never reach the log.
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
        requestExtra: _logAs(path),
      ),
    );
  }

  /// Sends the OTP finalize will need. Call only when [initiation] needs one.
  Future<NotifierState<bool>> requestTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    final (path, template) = switch (kind) {
      CoreTransferKind.intrabank => (
        CoreApiEndpoints.intrabankTransferOtp(initiation.reference),
        CoreApiEndpoints.intrabankTransferOtpTemplate,
      ),
      CoreTransferKind.interbank => (
        CoreApiEndpoints.interbankTransferOtp(initiation.reference),
        CoreApiEndpoints.interbankTransferOtpTemplate,
      ),
    };
    return NotifierState.fromResponse(
      await api.postData<bool>(
        path,
        parser: (_) => true,
        requestExtra: _logAs(template),
      ),
    );
  }

  /// Moves the money: sends exactly the checks [initiation] asked for, once.
  /// A missing OTP, or a check this app cannot satisfy, is refused before
  /// any request. Classify the reply with `mapCoreTransferSubmission`.
  Future<ServiceResponse<CoreTransferAck>> finalizeTransfer(
    CoreTransferKind kind,
    CoreTransferInitiation initiation, {
    required String pin,
    String? otp,
  }) async {
    final api = _api;
    if (api == null ||
        !initiation.supported ||
        (initiation.needsOtp && (otp == null || otp.isEmpty))) {
      return const ServiceResponse.blocked(_readUnavailable);
    }
    final (path, template) = switch (kind) {
      CoreTransferKind.intrabank => (
        CoreApiEndpoints.intrabankTransferFinalize(initiation.reference),
        CoreApiEndpoints.intrabankTransferFinalizeTemplate,
      ),
      CoreTransferKind.interbank => (
        CoreApiEndpoints.interbankTransferFinalize(initiation.reference),
        CoreApiEndpoints.interbankTransferFinalizeTemplate,
      ),
    };
    return api.postData<CoreTransferAck>(
      path,
      data: {'transactionPin': pin, if (initiation.needsOtp) 'otpCode': otp},
      parser: CoreTransferAck.fromJson,
      requestExtra: _logAs(template),
    );
  }

  /// The account name for a BOCTRUST recipient. Sensitive fields returned by
  /// the full Core enquiry are discarded by [NameEnquiryResult].
  Future<NotifierState<NameEnquiryResult>> boctrustNameEnquiry(
    String accountNumber,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_readUnavailable);
    if (!RegExp(r'^\d{10}$').hasMatch(accountNumber)) {
      return const NotifierState.error('Enter a 10-digit account number.');
    }
    return NotifierState.fromResponse(
      await api.getData<NameEnquiryResult>(
        CoreApiEndpoints.accountEnquiry(accountNumber),
        parser: NameEnquiryResult.fromJson,
        requestExtra: const {
          LoggingInterceptor.privacySensitivePathKey:
              CoreApiEndpoints.accountEnquiryTemplate,
        },
      ),
    );
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
        requestExtra: _logAs(CoreApiEndpoints.interbankNameEnquiry),
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
        requestExtra: _logAs(CoreApiEndpoints.interbankTransferStatusTemplate),
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
        requestExtra: _logAs(template),
      ),
    );
  }
}
