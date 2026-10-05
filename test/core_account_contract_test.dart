import 'package:boctrust_savings_loan/module/core_banking/model/bank_product_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _account(
  String productCode,
  String accountNumber, {
  String status = 'active',
  Object? availableBalance = '1250.50',
}) => {
  'productCode': productCode,
  'productName': '$productCode name',
  'accountNumber': accountNumber,
  'status': status,
  'openedAt': '2026-09-01T10:00:00.000Z',
  'availableBalance': availableBalance,
  'ledgerBalance': '1300.00',
};

void main() {
  group('CustomerBankAccountsData', () {
    test(
      'parses accounts and missing products, ignoring the numeric total',
      () {
        final data = CustomerBankAccountsData.fromJson({
          'totalAvailableBalance': 999999.99,
          'products': [
            _account('bocFlex', '0000000001'),
            _account('regular_savings', '0000000002', status: 'frozen'),
            {'productCode': 'broken'},
            _account('fixed', '0000000003', status: 'dormant'),
          ],
          'missingProducts': [
            {'productCode': 'target', 'productName': 'Target Savings'},
          ],
        });

        expect(data.accounts.map((a) => a.productCode), [
          'bocFlex',
          'regular_savings',
          'fixed',
        ]);
        expect(data.accounts.first.availableBalance, '1250.50');
        expect(data.accounts.first.openedAt, DateTime.utc(2026, 9, 1, 10));
        expect(data.accounts[1].status, CoreAccountStatus.frozen);
        expect(data.accounts[2].status, CoreAccountStatus.unknown);
        expect(data.missingProducts.single.productName, 'Target Savings');
        expect(data.activeFlexAccount?.accountNumber, '0000000001');
        expect(() => data.accounts.clear(), throwsUnsupportedError);
      },
    );

    test('a balance that is not a decimal string is not shown', () {
      final data = CustomerBankAccountsData.fromJson({
        'products': [
          _account('bocFlex', '0000000001', availableBalance: 1250.5),
          _account('other', '0000000002', availableBalance: '1e3'),
        ],
      });
      expect(data.accounts[0].availableBalance, isNull);
      expect(data.accounts[1].availableBalance, isNull);
    });

    test('a comma-grouped balance is kept as a plain decimal string', () {
      final data = CustomerBankAccountsData.fromJson({
        'totalAvailableBalance': 100,
        'products': [
          {
            ..._account('bocFlex', '1100925452'),
            'availableBalance': '100,000.00',
            'ledgerBalance': '1,234,567.89',
          },
          _account('a', '0000000002', availableBalance: '1,00.00'),
          _account('b', '0000000003', availableBalance: '1000,000.00'),
          _account('c', '0000000004', availableBalance: ',100.00'),
        ],
      });
      expect(data.activeFlexAccount?.availableBalance, '100000.00');
      expect(data.activeFlexAccount?.ledgerBalance, '1234567.89');
      expect(data.accounts[1].availableBalance, isNull);
      expect(data.accounts[2].availableBalance, isNull);
      expect(data.accounts[3].availableBalance, isNull);
    });

    test('the Flex account must be exactly one active account', () {
      CustomerBankAccount? flex(List<Map<String, Object?>> products) =>
          CustomerBankAccountsData.fromJson({
            'products': products,
          }).activeFlexAccount;

      expect(flex([_account('bocFlex', '1', status: 'frozen')]), isNull);
      expect(flex([_account('regular_savings', '1')]), isNull);
      expect(
        flex([_account('bocFlex', '1'), _account('bocFlex', '2')]),
        isNull,
      );
    });

    test('a duplicated account number is dropped entirely', () {
      final data = CustomerBankAccountsData.fromJson({
        'products': [
          _account('bocFlex', '0000000001'),
          _account('regular_savings', '0000000001'),
        ],
      });
      expect(data.accounts, isEmpty);
    });
  });

  test('bank products parse names without numeric terms', () {
    final products = CoreBankProduct.listFromJson([
      {
        'code': 'regular_savings',
        'name': 'Regular Savings',
        'description': 'Save regularly.',
        'interestRate': 7,
        'tenure': 30,
      },
      {'code': '', 'name': 'Nameless'},
      'nope',
    ]);

    expect(products.single.code, 'regular_savings');
    expect(products.single.description, 'Save regularly.');
    expect(() => products.add(products.first), throwsUnsupportedError);
  });
}
