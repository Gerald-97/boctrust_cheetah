import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../../core_banking/model/core_check_progress.dart';
import '../../core_banking/model/core_transfer_initiation.dart';
import '../model/transaction_limit_models.dart';
import '../model/transaction_limit_update_models.dart';

final coreTransactionLimitServiceProvider =
    Provider<CoreTransactionLimitService>(
      (ref) => CoreTransactionLimitService(ref.watch(coreApiServiceProvider)),
    );

/// Reads and changes the customer's Core transaction limits. A change is
/// initiate → PIN verify → OTP verify → bodyless finalize; each POST is sent
/// once and never retried, and the PIN and OTP are never kept. A null [_api]
/// means `CORE_BASE_URL` is not configured, so every call reports blocked.
class CoreTransactionLimitService {
  const CoreTransactionLimitService(this._api);
  final ApiService? _api;

  /// The caller's limits; 403 for a Tier 0 customer.
  Future<NotifierState<TransactionLimits>> getLimits() async {
    final api = _api;
    if (api == null) {
      return const NotifierState.blocked(
        'Transaction limits are not available right now.',
      );
    }
    return NotifierState.fromResponse(
      await api.getData<TransactionLimits>(
        CoreApiEndpoints.transactionLimits,
        parser: TransactionLimits.fromJson,
      ),
    );
  }

  static const _unavailable = 'Transaction limits are not available right now.';

  /// Starts a change of the limits in [draft]; an unchanged draft is never
  /// sent. Core checks each value against the tier ceiling (400).
  Future<NotifierState<CoreTransferInitiation>> initiateLimitUpdate(
    TransactionLimitDraft draft,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    if (draft.isEmpty) {
      return const NotifierState.error('Change at least one limit.');
    }
    return NotifierState.fromResponse(
      await api.postData<CoreTransferInitiation>(
        CoreApiEndpoints.transactionLimitsInitiate,
        data: draft.toJson(),
        parser: CoreTransferInitiation.fromJson,
      ),
    );
  }

  Future<NotifierState<CoreCheckProgress>> _check(
    String path, {
    Object? body,
  }) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    return NotifierState.fromResponse(
      await api.postData<CoreCheckProgress>(
        path,
        data: body,
        parser: CoreCheckProgress.fromJson,
      ),
    );
  }

  /// Verifies the PIN; Core then sends the OTP.
  Future<NotifierState<CoreCheckProgress>> verifyLimitPin(
    String reference,
    String pin,
  ) => _check(
    CoreApiEndpoints.transactionLimitPinVerify(reference),
    body: {'transactionPin': pin},
  );

  /// Sends the OTP again, on the customer's request after the PIN passed.
  Future<NotifierState<CoreCheckProgress>> resendLimitOtp(String reference) =>
      _check(CoreApiEndpoints.transactionLimitOtpResend(reference));

  Future<NotifierState<CoreCheckProgress>> verifyLimitOtp(
    String reference,
    String otp,
  ) => _check(
    CoreApiEndpoints.transactionLimitOtpVerify(reference),
    body: {'otpCode': otp},
  );

  /// Applies the change once both checks passed. No body. True on success;
  /// callers re-read [getLimits] for the values shown.
  Future<NotifierState<bool>> finalizeLimitUpdate(String reference) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_unavailable);
    return NotifierState.fromResponse(
      await api.postData<bool>(
        CoreApiEndpoints.transactionLimitFinalize(reference),
        parser: (_) => true,
      ),
    );
  }
}
