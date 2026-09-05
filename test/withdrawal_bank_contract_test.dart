import 'package:boctrust_savings_loan/module/account/model/withdrawal_bank_models.dart';
import 'package:flutter_test/flutter_test.dart';

WithdrawalBankAccount _accountWithNumber(String accountNumber) =>
    WithdrawalBankAccount.fromJson({
      'bankAccountId': 'account-1',
      'bankCode': '058',
      'bankName': 'GTBank',
      'accountNumber': accountNumber,
      'accountName': 'Ada Example',
      'nameMatchScore': '0.96',
      'provider': 'paystack',
      'createdAt': '2026-09-05T10:00:00.000Z',
    });

void main() {
  group('Withdrawal bank contracts', () {
    test('bank catalogue parses supported bank fields', () {
      final data = BankCatalogueData.fromJson({
        'banks': [
          {
            'name': 'Guaranty Trust Bank',
            'code': '058',
            'slug': 'guaranty-trust-bank',
            'country': 'Nigeria',
            'currency': 'NGN',
          },
        ],
      });
      expect(data.banks.single.code, '058');
    });

    test('resolution preserves decimal scores as strings', () {
      final data = ResolveWithdrawalBankAccountData.fromJson({
        'bankCode': '058',
        'bankName': 'GTBank',
        'accountNumber': '1234567890',
        'accountName': 'Ada Example',
        'nameMatchScore': '0.96',
        'minimumRequiredScore': '0.80',
        'isNameMatch': true,
      });
      expect(data.nameMatchScore, '0.96');
      expect(data.isNameMatch, isTrue);
    });

    test('list uses the server maximum', () {
      final data = WithdrawalBankAccountListData.fromJson({
        'bankAccounts': <Object?>[],
        'maxAllowed': 2,
      });
      expect(data.canAddAnother, isTrue);
    });

    test('masking never reveals a short account number in full', () {
      expect(_accountWithNumber('1234').maskedAccountNumber, '••••');
      expect(
        _accountWithNumber('0123456789').maskedAccountNumber,
        '••••••6789',
      );
    });

    test('requests reject anything but ten account digits', () {
      expect(
        () => ResolveWithdrawalBankAccountRequest(
          bankCode: '058',
          bankName: 'GTBank',
          accountNumber: '12345',
        ),
        throwsFormatException,
      );
      expect(
        () => AddWithdrawalBankAccountRequest(
          bankCode: '058',
          bankName: 'GTBank',
          accountNumber: '01234567890',
        ),
        throwsFormatException,
      );
      expect(
        () => AddWithdrawalBankAccountRequest(
          bankCode: '  ',
          bankName: 'GTBank',
          accountNumber: '0123456789',
        ),
        throwsFormatException,
      );
    });

    test('a valid request emits exactly the published keys', () {
      final json = ResolveWithdrawalBankAccountRequest(
        bankCode: '058',
        bankName: 'Guaranty Trust Bank',
        accountNumber: '0123456789',
      ).toJson();
      expect(json, {
        'bankCode': '058',
        'bankName': 'Guaranty Trust Bank',
        'accountNumber': '0123456789',
      });
    });

    test('a list at the server maximum cannot take another account', () {
      final data = WithdrawalBankAccountListData.fromJson({
        'bankAccounts': [
          {
            'bankAccountId': 'account-1',
            'bankCode': '058',
            'bankName': 'GTBank',
            'accountNumber': '0123456789',
            'accountName': 'Ada Example',
          },
        ],
        'maxAllowed': 1,
      });
      expect(data.canAddAnother, isFalse);
    });

    test('delete confirms which account the server removed', () {
      final data = DeleteWithdrawalBankAccountData.fromJson({
        'bankAccountId': 'account-1',
        'status': 'deleted',
      });
      expect(data.bankAccountId, 'account-1');
      expect(data.status, 'deleted');
    });
  });
}
