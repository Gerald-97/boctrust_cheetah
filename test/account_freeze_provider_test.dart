import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/account_freeze_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/account_freeze_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

const _number = '0000000001';

class _FreezeCore extends CoreAccountService {
  _FreezeCore({this.unfreeze = const FreezeConflict()}) : super(null);

  final AccountFreezeOutcome<AccountFreezeResult> unfreeze;
  var posts = 0;
  var singleReads = 0;

  @override
  Future<NotifierState<CustomerBankAccountsData>> getBankAccounts() async =>
      NotifierState.done(
        CustomerBankAccountsData.fromJson({
          'products': [_row('frozen')],
        }),
      );

  @override
  Future<NotifierState<CustomerBankAccount>> getBankAccount(
    String accountNumber,
  ) async {
    singleReads++;
    return NotifierState.done(CustomerBankAccount.tryParse(_row('frozen'))!);
  }

  @override
  Future<AccountFreezeOutcome<AccountFreezeResult>> freezeAccount(
    String accountNumber,
    String transactionPin,
  ) async {
    posts++;
    return const FreezeConflict();
  }

  @override
  Future<AccountFreezeOutcome<AccountFreezeResult>> unfreezeAccount(
    String accountNumber,
    String transactionPin,
    String otpCode,
  ) async {
    posts++;
    return unfreeze;
  }
}

Map<String, Object?> _row(String status) => {
  'productCode': 'bocFlex',
  'productName': 'Boc Flex',
  'accountNumber': _number,
  'status': status,
  'availableBalance': '100.00',
};

ProviderContainer _container(_FreezeCore core) {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(core),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a bank-frozen unfreeze ends bank-frozen and is remembered', () async {
    final container = _container(
      _FreezeCore(unfreeze: const FreezeBankFrozen()),
    );

    await container
        .read(accountFreezeProvider(_number).notifier)
        .unfreeze('1234', '654321');

    expect(
      container.read(accountFreezeProvider(_number)).phase,
      AccountFreezePhase.bankFrozen,
    );
    expect(
      container.read(accountFreezeMemoryProvider)[_number],
      CoreFrozenBy.admin,
    );
  });

  test('a 409 re-reads the account and sends no second POST', () async {
    final core = _FreezeCore();
    final container = _container(core);
    await container.read(customerBankAccountsProvider.notifier).load();

    await container
        .read(accountFreezeProvider(_number).notifier)
        .freeze('1234');

    expect(core.posts, 1);
    expect(core.singleReads, 1);
    expect(
      container.read(accountFreezeProvider(_number)).phase,
      AccountFreezePhase.idle,
    );
  });
}
