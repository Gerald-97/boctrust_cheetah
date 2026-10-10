import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/core_transfer_requery_models.dart';
import '../model/interbank_models.dart';

final coreTransferServiceProvider = Provider<CoreTransferService>(
  (ref) => CoreTransferService(ref.watch(coreApiServiceProvider)),
);

/// Core transfer reads: recipient lookups, banks, and live status of a
/// transfer already sent. The single-step submit routes left the Core docs;
/// staged transfers (initiate, OTP, finalize) are not built yet.
class CoreTransferService {
  const CoreTransferService(this._api);
  final ApiService? _api;

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
