import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/beneficiary_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bill_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_money.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interbank', () {
    test('banks parse from a list or a wrapped list, deduped by code', () {
      final banks = CommercialBank.listFromJson([
        {'code': '000014', 'id': 1, 'name': 'Zenith'},
        {'code': 58, 'name': 'Access'},
        {'code': '000014', 'name': 'Duplicate'},
        {'name': 'No code'},
      ]);
      expect(banks.map((b) => (b.code, b.name)), [
        ('58', 'Access'),
        ('000014', 'Zenith'),
      ]);
      expect(
        CommercialBank.listFromJson({
          'banks': [
            {'bankCode': '011', 'bankName': 'First'},
          ],
        }).single.code,
        '011',
      );
    });

    test('name enquiry keeps only the name', () {
      expect(
        NameEnquiryResult.fromJson({
          'name': ' ADA OBI ',
          'bvn': '22222222222',
          'kyc': '3',
        }).name,
        'ADA OBI',
      );
      expect(NameEnquiryResult.fromJson({'accountName': 'IKE'}).name, 'IKE');
      expect(() => NameEnquiryResult.fromJson({}), throwsFormatException);
    });

    test('transfer and status bodies', () {
      const draft = InterbankTransferDraft(
        bankCode: '000014',
        bankName: 'Zenith',
        accountNumber: '0123456789',
        accountName: 'ADA OBI',
        amountKobo: '5000',
        narration: '  ',
      );
      expect(draft.toJson(), {
        'receiverBankCode': '000014',
        'receiverAccountNumber': '0123456789',
        'amount': '5000',
      });
      final status = InterbankTransferStatus.fromJson({
        'reference': 'R1',
        'status': 'completed',
      });
      expect(status.state, InterbankTransferState.completed);
      expect(
        InterbankTransferStatus.fromJson({'status': 'weird'}).state,
        InterbankTransferState.unknown,
      );
    });

    test('a 500 on an interbank transfer means the recipient was not '
        'resolved', () {
      const response = ServiceResponse<CoreTransferAck>(
        status: ServiceStatus.error,
        statusCode: 500,
      );
      expect(
        mapCoreSubmission(response, interbank: true),
        const RejectedSubmission(CoreRejection.recipientUnresolved),
      );
      expect(mapCoreSubmission(response), const UnknownSubmission());
    });
  });

  test('a BOCTRUST transfer sends account number, amount and narration', () {
    expect(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '1000',
        narration: 'Rent',
      ).toJson(),
      {'toAccountNumber': '1100037777', 'amount': '1000', 'narration': 'Rent'},
    );
  });

  group('bills', () {
    test('categories, billers and items parse leniently', () {
      final categories = BillerCategory.listFromJson([
        {'id': 4, 'name': 'Mobile/Recharge', 'isAirtime': true},
        {'id': '9', 'name': 'Subscriptions'},
        {'name': 'no id'},
      ]);
      expect(categories.map((c) => c.id), ['4', '9']);

      final billers = Biller.listFromJson({
        'billers': [
          {
            'billerId': 157,
            'billerCategoryId': '9',
            'categoryName': 'Cable TV Bills',
            'name': 'DSTV',
            'customerField1': 'SmartCard No',
            'isActive': true,
          },
          {'billerId': 158, 'billerCategoryId': '9', 'name': 'Off'},
          {
            'billerId': 159,
            'billerCategoryId': 9,
            'name': 'Off',
            'isActive': false,
          },
        ],
      });
      expect(billers.map((b) => b.id), ['157', '158']);
      expect(billers.first.customerFieldLabel, 'SmartCard No');
      expect(billers.first.categoryName, 'Cable TV Bills');
      expect(billers.last.customerFieldLabel, 'Customer ID');

      final items = PaymentItem.listFromJson([
        {'id': 'a', 'billerId': 157, 'name': 'Compact', 'amount': 15700},
        {'id': 'b', 'billerId': '157', 'name': 'Any', 'amount': 0},
        {'id': 'c', 'billerId': '157', 'name': 'Odd', 'amount': 1.005},
        {'id': 'd', 'billerId': '157', 'name': 'Text', 'amount': '250.5'},
      ]);
      expect(items.map((i) => i.amountNaira), [
        '15700.00',
        null,
        null,
        '250.50',
      ]);
      expect(items.first.billerId, '157');
    });

    test('a payment sends only the four documented keys', () {
      expect(
        const BillPaymentDraft(
          billerId: '157',
          paymentItemId: 'a',
          customerId: '1234567890',
          amountNaira: '100.00',
        ).toJson(),
        {
          'billerId': '157',
          'paymentItemId': 'a',
          'customerId': '1234567890',
          'amount': '100.00',
        },
      );
    });

    test('bill amounts are two-decimal Naira strings', () {
      expect(
        parseNairaAmount('1,000.5', maxKobo: '1000000'),
        const ValidMoney('1000.50'),
      );
      expect(parseNairaAmount('2', maxKobo: '100'), isA<InvalidMoney>());
      expect(koboToNaira('5'), '0.05');
      expect(koboToNaira('123456'), '1234.56');
    });
  });

  group('beneficiaries', () {
    test('parse and requests', () {
      final rows = Beneficiary.listFromJson([
        {
          'beneficiaryId': 'b1',
          'type': 'bank_account',
          'number': '0123456789',
          'name': 'ADA OBI',
          'bankCode': '058',
          'bankName': 'GTB',
          'createdAt': '2026-10-05T10:00:00.000Z',
        },
        {'beneficiaryId': 'b2', 'type': 'gift', 'number': '1', 'name': 'x'},
        {'type': 'water', 'number': '1', 'name': 'no id'},
      ]);
      expect(rows.map((b) => (b.id, b.type)), [
        ('b1', BeneficiaryType.bankAccount),
        ('b2', null),
      ]);
      expect(rows.first.maskedNumber, '•••• 6789');

      expect(
        bankBeneficiaryRequest(
          bankCode: '058',
          number: '0123456789',
          nickname: ' ',
        ),
        {'type': 'bank_account', 'bankCode': '058', 'number': '0123456789'},
      );
      // A bill customer is saved under its tile, wherever Core files it.
      BeneficiaryType? typeOf(String name, String category) => BillerGroup.of(
        Biller(id: '1', categoryId: '1', name: name, categoryName: category),
      )?.beneficiaryType;
      expect(typeOf('EKEDC NEW', 'Utility Bills'), BeneficiaryType.electricity);
      expect(typeOf('DSTV', 'Cable TV Bills'), BeneficiaryType.cableTv);
      expect(typeOf('MTN', 'Mobile/Recharge'), isNull);
    });
  });

  test('bill tiles match billers across categories', () {
    Biller biller(String name, {String category = 'Others', String? field}) =>
        Biller(
          id: name,
          categoryId: '1',
          categoryName: category,
          name: name,
          customerFieldLabel: field ?? 'Customer ID',
        );
    final billers = [
      biller('MTN', category: 'Mobile/Recharge'),
      biller('WAEC Payments', category: 'Mobile/Recharge'),
      biller('Airtel Data', category: 'Mobile/Recharge'),
      biller('Airtel Data Plans'),
      biller('Kano Electricity', category: 'Airlines'),
      biller('EKEDC NEW', category: 'Utility Bills', field: 'Meter No'),
      biller('Lagos Water Corporation', category: 'Utility Bills'),
      biller('DSTV Subscriptions', category: 'Cable TV Bills'),
      biller('Pay IPNX subscriptions', category: 'Subscriptions'),
      biller('Covenant University Fees Payment', category: 'PayChoice'),
    ];
    List<String> names(BillerGroup group) => [
      for (final b in billers)
        if (group.matches(b)) b.name,
    ];

    expect(names(BillerGroup.airtime), ['MTN']);
    expect(names(BillerGroup.data), ['Airtel Data', 'Airtel Data Plans']);
    expect(names(BillerGroup.electricity), ['Kano Electricity', 'EKEDC NEW']);
    expect(names(BillerGroup.water), ['Lagos Water Corporation']);
    expect(names(BillerGroup.cableTv), ['DSTV Subscriptions']);
    expect(names(BillerGroup.internet), ['Pay IPNX subscriptions']);
    expect(names(BillerGroup.education), [
      'WAEC Payments',
      'Covenant University Fees Payment',
    ]);
  });
}
