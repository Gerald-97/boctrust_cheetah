import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_activity_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'products': [
        {
          'productCode': kFlexProductCode,
          'productName': 'Boc Flex',
          'accountNumber': '1100927896',
          'status': 'active',
        },
      ],
    }),
  );
}

class _History extends CoreAccountService {
  _History() : super(null);

  final requests = <(String, CoreHistoryRange)>[];
  int version = 0;

  @override
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async {
    requests.add((accountNumber, range));
    return NotifierState.done(
      CoreTransactionPage(
        rows: [
          CoreAccountTransaction(
            id: 'row-$version',
            type: CoreTransactionType.debit,
            amount: '10.00',
          ),
        ],
      ),
    );
  }
}

void main() {
  test('refresh calls Core even when history is not on screen', () async {
    final service = _History();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreAccountServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(refreshFlexTransactionHistoryProvider)();

    expect(service.requests, [('1100927896', CoreHistoryRange.last30Days)]);
  });

  test('refresh replaces the visible recent transactions', () async {
    final service = _History();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreAccountServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final key = (
      accountNumber: '1100927896',
      range: CoreHistoryRange.last30Days,
    );
    final subscription = container.listen(
      coreAccountHistoryProvider(key),
      (_, _) {},
    );
    addTearDown(subscription.close);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(coreAccountHistoryProvider(key)).data?.rows.single.id,
      'row-0',
    );

    service.version = 1;
    await container.read(refreshFlexTransactionHistoryProvider)();

    expect(service.requests.length, 2);
    expect(
      container.read(coreAccountHistoryProvider(key)).data?.rows.single.id,
      'row-1',
    );
  });
}
