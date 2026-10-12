import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/savings/model/flex_interest_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_flex_interest_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Interest extends CoreFlexInterestService {
  const _Interest(this.result) : super(null);
  final NotifierState<FlexInterest> result;

  @override
  Future<NotifierState<FlexInterest>> getInterest() async => result;
}

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'products': [
        {
          'productCode': kFlexProductCode,
          'productName': 'Boc Flex',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': '125.00',
        },
      ],
    }),
  );

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

Future<void> _open(
  WidgetTester tester,
  NotifierState<FlexInterest> result,
) async {
  await pumpFlow(
    tester,
    route: AppRoutes.flexSave,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      coreFlexInterestServiceProvider.overrideWithValue(_Interest(result)),
      featureAvailabilityProvider(
        FeatureCapability.flexInterestView,
      ).overrideWithValue(FeatureAvailability.available),
      userHomeProvider.overrideWith(LayoutHome.new),
      customerBankAccountsProvider.overrideWith(_Accounts.new),
      coreBankProductsProvider.overrideWith(LayoutCoreProducts.new),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('reads the Flex interest summary', () {
    final interest = FlexInterest.fromJson({
      'accountNumber': '0000000001',
      'ratePercent': '12.5',
      'currentMonthAccruedInterest': '84.10',
      'totalInterestEarned': '1203.55',
    });

    expect(interest.ratePercent, '12.5');
    expect(interest.currentMonthAccruedInterest, '84.10');
    expect(interest.totalInterestEarned, '1203.55');
  });

  testWidgets('the Flex screen shows interest', (tester) async {
    await _open(
      tester,
      const NotifierState.done(
        FlexInterest(
          ratePercent: '12.5',
          currentMonthAccruedInterest: '84.10',
          totalInterestEarned: '1203.55',
        ),
      ),
    );

    expect(find.text('12.5% p.a.'), findsOneWidget);
    expect(find.text('This month so far'), findsOneWidget);
    expect(find.text('₦84.10'), findsOneWidget);
    expect(find.text('Total interest earned'), findsOneWidget);
    expect(find.text('₦1,203.55'), findsOneWidget);
  });

  testWidgets('no rate is shown plainly', (tester) async {
    await _open(
      tester,
      const NotifierState.done(
        FlexInterest(
          currentMonthAccruedInterest: '84.10',
          totalInterestEarned: '1203.55',
        ),
      ),
    );
    expect(find.textContaining('% p.a.'), findsNothing);
    expect(find.text('₦84.10'), findsOneWidget);
  });

  testWidgets('no Flex account hides the interest card silently', (
    tester,
  ) async {
    await _open(
      tester,
      const NotifierState.error('No Flex account.', statusCode: 404),
    );
    expect(find.text('Total interest earned'), findsNothing);
    expect(find.text('No Flex account.'), findsNothing);
  });
}
