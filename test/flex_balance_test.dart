import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/flex_balance.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:flutter_test/flutter_test.dart';

FlexWalletData _wallet(String status) => FlexWalletData.fromJson({
  'walletType': 'bocFlex',
  'currency': 'NGN',
  'availableBalance': '0.0000',
  'ledgerBalance': '0.0000',
  'status': status,
});

void main() {
  test('Core Flex wins; the User wallet covers customers without one', () {
    final core = CustomerBankAccountsData.fromJson({
      'products': [
        {
          'productCode': 'bocFlex',
          'productName': 'Boc Flex',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': '75.00',
        },
      ],
    });
    final noCoreAccounts = CustomerBankAccountsData.fromJson({'products': []});

    final fromCore = resolveFlexBalance(core: core, wallet: _wallet('active'));
    expect(fromCore?.availableBalance, '75.00');
    expect(fromCore?.accountNumber, '0000000001');

    final fromUser = resolveFlexBalance(
      core: noCoreAccounts,
      wallet: _wallet('active'),
    );
    expect(fromUser?.availableBalance, '0.0000');
    expect(fromUser?.accountNumber, isNull);

    expect(
      resolveFlexBalance(core: noCoreAccounts, wallet: _wallet('frozen')),
      isNull,
    );
  });

  test('a frozen Core Flex keeps its Core balance over the User wallet', () {
    final core = CustomerBankAccountsData.fromJson({
      'products': [
        {
          'productCode': 'bocFlex',
          'productName': 'Boc Flex',
          'accountNumber': '0000000001',
          'status': 'frozen',
          'availableBalance': '75.00',
        },
      ],
    });

    final balance = resolveFlexBalance(core: core, wallet: _wallet('active'));
    expect(balance?.availableBalance, '75.00');
    expect(balance?.accountNumber, '0000000001');
    expect(balance?.isFrozen, isTrue);
  });
}
