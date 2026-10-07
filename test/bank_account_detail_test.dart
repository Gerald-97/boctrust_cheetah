import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_summary.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CoreAccountService {
  const _Accounts() : super(null);

  @override
  Future<NotifierState<CoreAccountSummary>> getAccountSummary(
    String accountNumber,
  ) async => NotifierState.done(
    CoreAccountSummary(
      accountNumber: accountNumber,
      status: CoreAccountStatus.active,
      name: 'ADA OBI',
      product: 'Boc Flex',
      availableBalance: '7654.30',
    ),
  );
}

void main() {
  testWidgets('account detail shows the live summary', (tester) async {
    await pumpFlow(
      tester,
      route: AppRoutes.bankAccountDetail,
      arguments: const AppRouteArguments(entityId: '1100919408'),
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        coreAccountServiceProvider.overrideWithValue(const _Accounts()),
        featureAvailabilityProvider(
          FeatureCapability.coreAccountActivity,
        ).overrideWithValue(FeatureAvailability.available),
      ],
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Boc Flex'), findsWidgets);
    expect(find.text('₦7,654.30'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
  });
}
