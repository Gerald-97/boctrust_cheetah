import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _History extends CoreAccountService {
  _History() : super(null);

  @override
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async => NotifierState.done(
    CoreTransactionPage(
      rows: const [
        CoreAccountTransaction(
          id: '1',
          type: CoreTransactionType.credit,
          amount: '5000.00',
          narration: 'SALARY',
          reversed: false,
        ),
      ],
      page: CorePage(page: page, pageSize: pageSize, total: 1, totalPages: 1),
    ),
  );
}

class _Accounts extends CustomerBankAccountsNotifier {
  _Accounts({required this.withFlex});
  final bool withFlex;

  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'products': [
        if (withFlex)
          {
            'productCode': kFlexProductCode,
            'productName': 'Boc Flex',
            'accountNumber': '1100919408',
            'status': 'active',
          },
      ],
    }),
  );

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

Future<void> _open(WidgetTester tester, {required bool withFlex}) async {
  await pumpFlow(
    tester,
    route: AppRoutes.transactionHistory,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(_History()),
      customerBankAccountsProvider.overrideWith(
        () => _Accounts(withFlex: withFlex),
      ),
      featureAvailabilityProvider(
        FeatureCapability.transactionHistory,
      ).overrideWithValue(FeatureAvailability.available),
      featureAvailabilityProvider(
        FeatureCapability.coreAccountHistory,
      ).overrideWithValue(FeatureAvailability.available),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets("payments history lists the Flex account's transactions", (
    tester,
  ) async {
    await _open(tester, withFlex: true);

    expect(find.text('SALARY'), findsOneWidget);
    expect(find.text('+₦5,000.00'), findsOneWidget);
  });

  testWidgets('payments history without a Flex account says so', (
    tester,
  ) async {
    await _open(tester, withFlex: false);

    expect(find.text('You have no Boc Flex account yet.'), findsOneWidget);
  });
}
