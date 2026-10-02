import 'dart:async';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

class _Accounts extends CoreAccountService {
  _Accounts() : super(ApiService(Dio()));

  final response = Completer<NotifierState<CustomerBankAccountsData>>();

  @override
  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() =>
      response.future;
}

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('unconfigured Core reports unavailable instead of throwing', () async {
    final service = const CoreAccountService(null);

    expect((await service.getBankAccounts()).status, ServiceStatus.blocked);
    expect((await service.getBankProducts()).status, ServiceStatus.blocked);
  });

  test('a response landing after clear cannot repopulate balances', () async {
    final accounts = _Accounts();
    final container = _container([
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(accounts),
    ]);
    final notifier = container.read(customerBankAccountsProvider.notifier);

    final pending = notifier.load();
    notifier.clear();
    accounts.response.complete(
      NotifierState.done(CustomerBankAccountsData.fromJson({'products': []})),
    );
    await pending;

    expect(
      container.read(customerBankAccountsProvider).status,
      ServiceStatus.idle,
    );
  });

  test('no session means no Core account request', () async {
    final accounts = _Accounts();
    final container = _container([
      authSessionProvider.overrideWith(SignedOutSavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(accounts),
    ]);

    await container.read(customerBankAccountsProvider.notifier).load();

    expect(
      container.read(customerBankAccountsProvider).status,
      ServiceStatus.idle,
    );
  });

  test('refreshing one account replaces only that balance', () async {
    final accounts = _SingleAccount();
    final container = _container([
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(accounts),
    ]);
    final notifier = container.read(customerBankAccountsProvider.notifier);
    await notifier.load();

    await notifier.refreshAccount('0000000001');

    final data = container.read(customerBankAccountsProvider).data!;
    expect(accounts.singleCalls, ['0000000001']);
    expect(data.accounts.first.availableBalance, '900.00');
    expect(data.accounts.last.availableBalance, '50.00');
  });
}

Map<String, Object?> _row(String code, String number, String balance) => {
  'productCode': code,
  'productName': code,
  'accountNumber': number,
  'status': 'active',
  'availableBalance': balance,
};

class _SingleAccount extends CoreAccountService {
  _SingleAccount() : super(ApiService(Dio()));

  final singleCalls = <String>[];

  @override
  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() async =>
      NotifierState.done(
        CustomerBankAccountsData.fromJson({
          'products': [
            _row('bocFlex', '0000000001', '100.00'),
            _row('bocSmartSave', '0000000002', '50.00'),
          ],
        }),
      );

  @override
  Future<NotifierState<CustomerBankAccount>> getBankAccount(
    String accountNumber,
  ) async {
    singleCalls.add(accountNumber);
    return NotifierState.done(
      CustomerBankAccount.tryParse(_row('bocFlex', accountNumber, '900.00'))!,
    );
  }
}
