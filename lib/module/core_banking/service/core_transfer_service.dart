import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_submission_models.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';

final coreTransferServiceProvider = Provider<CoreTransferService>(
  (ref) => CoreTransferService(ref.watch(coreApiServiceProvider)),
);

/// Core transfers. Each money-moving method sends exactly one POST with the
/// customer's transaction PIN and never retries; the caller classifies the
/// result with `mapCoreTransferSubmission`. The PIN is used only for that
/// request body and never kept.
class CoreTransferService {
  const CoreTransferService(this._api);
  final ApiService? _api;

  /// Blocked replies are never sent, so they classify as a rejection.
  static const _unconfigured = ServiceResponse<CoreTransferAck>(
    status: ServiceStatus.blocked,
    message: 'Transfers are not available right now.',
  );

  Future<ServiceResponse<CoreTransferAck>> moveBetweenOwnAccounts(
    OwnAccountMoveDraft draft, {
    required String transactionPin,
  }) async {
    final api = _api;
    if (api == null) return _unconfigured;
    return api.postData<CoreTransferAck>(
      draft.direction == OwnAccountDirection.toSavings
          ? CoreApiEndpoints.ownAccountTransfer
          : CoreApiEndpoints.intrabankWithdrawals,
      data: {...draft.toJson(), 'transactionPin': transactionPin},
      parser: CoreTransferAck.fromJson,
    );
  }

  Future<ServiceResponse<CoreTransferAck>> transferToBoctrust(
    BoctrustTransferDraft draft, {
    required String transactionPin,
  }) async {
    final api = _api;
    if (api == null) return _unconfigured;
    return api.postData<CoreTransferAck>(
      CoreApiEndpoints.intrabankTransfers,
      data: {...draft.toJson(), 'transactionPin': transactionPin},
      parser: CoreTransferAck.fromJson,
    );
  }

  /// Classify with `mapCoreTransferSubmission(response, interbank: true)`.
  Future<ServiceResponse<CoreTransferAck>> transferToOtherBank(
    InterbankTransferDraft draft, {
    required String transactionPin,
  }) async {
    final api = _api;
    if (api == null) return _unconfigured;
    return api.postData<CoreTransferAck>(
      CoreApiEndpoints.interbankTransfers,
      data: {...draft.toJson(), 'transactionPin': transactionPin},
      parser: CoreTransferAck.fromJson,
    );
  }

  static const _readUnavailable = 'Transfers are not available right now.';

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
    final path = switch (tracking.kind) {
      CoreTransferKind.intrabank => CoreApiEndpoints.intrabankTransferRequery(
        tracking.value,
      ),
      CoreTransferKind.interbank => CoreApiEndpoints.interbankTransferRequery(
        tracking.value,
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
