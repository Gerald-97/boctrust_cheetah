import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/core_api_endpoints.dart';
import '../../../app/core_network.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/account_freeze_models.dart';
import '../model/bank_product_models.dart';
import '../model/core_account_summary.dart';
import '../model/core_account_transactions.dart';
import '../model/customer_bank_account_models.dart';

const _coreUnavailable = 'Account services are not available right now.';

final _accountNumber = RegExp(r'^\d{10}$');

final coreAccountServiceProvider = Provider<CoreAccountService>(
  (ref) => CoreAccountService(ref.watch(coreApiServiceProvider)),
);

/// Reads the customer's Core accounts and the Core product catalogue.
///
/// A null [_api] means `CORE_BASE_URL` is not configured; every read then
/// reports blocked rather than throwing or inventing empty data.
class CoreAccountService {
  const CoreAccountService(this._api);
  final ApiService? _api;

  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    return NotifierState.fromResponse(
      await api.getData<CustomerBankAccountsData>(
        CoreApiEndpoints.bankAccounts,
        parser: CustomerBankAccountsData.fromJson,
      ),
    );
  }

  /// One of the caller's accounts with a live balance. A number that is not
  /// ten digits is never sent.
  Future<NotifierState<CustomerBankAccount>> getBankAccount(
    String accountNumber,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    if (!_accountNumber.hasMatch(accountNumber)) {
      return const NotifierState.error('Account not found.');
    }
    return NotifierState.fromResponse(
      await api.getData<CustomerBankAccount>(
        CoreApiEndpoints.bankAccount(accountNumber),
        parser: (json) =>
            CustomerBankAccount.tryParse(json) ??
            (throw const FormatException('Invalid account.')),
      ),
    );
  }

  /// A live summary of one of the caller's accounts. A number that is not
  /// ten digits is never sent.
  Future<NotifierState<CoreAccountSummary>> getAccountSummary(
    String accountNumber,
  ) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    if (!_accountNumber.hasMatch(accountNumber)) {
      return const NotifierState.error('Account not found.');
    }
    return NotifierState.fromResponse(
      await api.getData<CoreAccountSummary>(
        CoreApiEndpoints.bankAccountSummary(accountNumber),
        parser: CoreAccountSummary.fromJson,
      ),
    );
  }

  /// One page of live transaction rows for one of the caller's accounts over
  /// [range].
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    if (!_accountNumber.hasMatch(accountNumber)) {
      return const NotifierState.error('Account not found.');
    }
    final (:fromDate, :toDate) = range.window(today ?? DateTime.now());
    return NotifierState.fromResponse(
      await api.getData<CoreTransactionPage>(
        CoreApiEndpoints.bankAccountTransactions(accountNumber),
        queryParameters: {
          'fromDate': fromDate,
          'toDate': toDate,
          'page': page,
          'pageSize': pageSize,
        },
        parser: CoreTransactionPage.fromJson,
      ),
    );
  }

  Future<NotifierState<List<CoreBankProduct>>> getBankProducts() async {
    final api = _api;
    if (api == null) return const NotifierState.blocked(_coreUnavailable);
    return NotifierState.fromResponse(
      await api.getData<List<CoreBankProduct>>(
        CoreApiEndpoints.bankProducts,
        parser: CoreBankProduct.listFromJson,
      ),
    );
  }

  /// Freezes [accountNumber]. The PIN goes only in this request's body.
  Future<AccountFreezeOutcome<AccountFreezeResult>> freezeAccount(
    String accountNumber,
    String transactionPin,
  ) => _freezeWrite(
    accountNumber,
    CoreApiEndpoints.bankAccountFreeze,
    CoreApiEndpoints.bankAccountFreezeTemplate,
    {'transactionPin': transactionPin},
    AccountFreezeResult.fromJson,
  );

  /// Asks Core to send the code that confirms an unfreeze. Calling it again
  /// resends; there is no separate route.
  Future<AccountFreezeOutcome<UnfreezeOtpReply>> sendUnfreezeOtp(
    String accountNumber,
  ) => _freezeWrite(
    accountNumber,
    CoreApiEndpoints.bankAccountUnfreezeOtp,
    CoreApiEndpoints.bankAccountUnfreezeOtpTemplate,
    null,
    UnfreezeOtpReply.fromJson,
  );

  /// Unfreezes [accountNumber]. The PIN and code go only in this request's
  /// body.
  Future<AccountFreezeOutcome<AccountFreezeResult>> unfreezeAccount(
    String accountNumber,
    String transactionPin,
    String otpCode,
  ) => _freezeWrite(
    accountNumber,
    CoreApiEndpoints.bankAccountUnfreeze,
    CoreApiEndpoints.bankAccountUnfreezeTemplate,
    {'transactionPin': transactionPin, 'otpCode': otpCode},
    AccountFreezeResult.fromJson,
  );

  /// Sends exactly one POST and never retries. The logger is given only the
  /// path template, so the PIN, the code and Core's staging-only `otpCode`
  /// never reach a log line.
  Future<AccountFreezeOutcome<T>> _freezeWrite<T>(
    String accountNumber,
    String Function(String accountNumber) path,
    String template,
    Map<String, Object?>? body,
    T Function(Object? json) parser,
  ) async {
    if (!_accountNumber.hasMatch(accountNumber)) {
      return FreezeNotFound<T>();
    }
    final api = _api;
    if (api == null) return FreezeUncertain<T>();
    final response = await api.postData<T>(
      path(accountNumber),
      data: body,
      parser: parser,
      requestExtra: {LoggingInterceptor.privacySensitivePathKey: template},
    );
    if (response.status == ServiceStatus.success && response.data is T) {
      return FreezeSucceeded<T>(response.data as T);
    }
    // A 401 the client produced for an expired session was never sent.
    if (response.errorCode == kLocalSessionExpiredCode) {
      return FreezeUncertain<T>();
    }
    return switch (response.statusCode) {
      401 => FreezeWrongCredentials<T>(),
      403 => FreezeBankFrozen<T>(),
      404 => FreezeNotFound<T>(),
      409 => FreezeConflict<T>(),
      _ => FreezeUncertain<T>(),
    };
  }
}
