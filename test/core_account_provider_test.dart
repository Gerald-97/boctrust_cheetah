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
}
