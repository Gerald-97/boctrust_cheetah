import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/withdrawal_bank_models.dart';

final withdrawalBankServiceProvider = Provider<WithdrawalBankService>(
  (ref) => WithdrawalBankService(ref.watch(apiServiceProvider)),
);

/// The six published bank and withdrawal-account operations.
///
/// Everything goes through the authenticated User Service client. Resolution is
/// a server concern: no Paystack key is held here and no request is made
/// directly to a provider.
class WithdrawalBankService {
  const WithdrawalBankService(this._api);
  final ApiService _api;

  Future<NotifierState<BankCatalogueData>> getBanks() async =>
      NotifierState.fromResponse(
        await _api.getData<BankCatalogueData>(
          ApiEndpoints.banks,
          parser: BankCatalogueData.fromJson,
        ),
      );

  Future<NotifierState<WithdrawalBankAccountListData>> listAccounts() async =>
      NotifierState.fromResponse(
        await _api.getData<WithdrawalBankAccountListData>(
          ApiEndpoints.withdrawalBankAccounts,
          parser: WithdrawalBankAccountListData.fromJson,
        ),
      );

  Future<NotifierState<WithdrawalBankAccount>> getAccount(
    String bankAccountId,
  ) async => NotifierState.fromResponse(
    await _api.getData<WithdrawalBankAccount>(
      ApiEndpoints.withdrawalBankAccount(bankAccountId),
      parser: WithdrawalBankAccount.fromJson,
    ),
  );

  /// Checks the account name against the profile before anything is saved.
  Future<NotifierState<ResolveWithdrawalBankAccountData>> resolveAccount(
    ResolveWithdrawalBankAccountRequest request,
  ) async => NotifierState.fromResponse(
    await _api.postData<ResolveWithdrawalBankAccountData>(
      ApiEndpoints.resolveWithdrawalBankAccount,
      data: request.toJson(),
      parser: ResolveWithdrawalBankAccountData.fromJson,
    ),
  );

  Future<NotifierState<AddWithdrawalBankAccountData>> addAccount(
    AddWithdrawalBankAccountRequest request,
  ) async => NotifierState.fromResponse(
    await _api.postData<AddWithdrawalBankAccountData>(
      ApiEndpoints.withdrawalBankAccounts,
      data: request.toJson(),
      parser: AddWithdrawalBankAccountData.fromJson,
    ),
  );

  Future<NotifierState<DeleteWithdrawalBankAccountData>> deleteAccount(
    String bankAccountId,
  ) async => NotifierState.fromResponse(
    await _api.deleteData<DeleteWithdrawalBankAccountData>(
      ApiEndpoints.withdrawalBankAccount(bankAccountId),
      parser: DeleteWithdrawalBankAccountData.fromJson,
    ),
  );
}
