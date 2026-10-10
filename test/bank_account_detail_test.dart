import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_summary.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CoreAccountService {
  const _Accounts([this.rows = const []]) : super(null);
  final List<Object?> rows;

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

  @override
  Future<NotifierState<List<Object?>>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int numberOfItems = 50,
    DateTime? today,
  }) async => NotifierState.done(rows);
}

Future<void> _pumpDetail(WidgetTester tester, _Accounts accounts) async {
  await pumpFlow(
    tester,
    route: AppRoutes.bankAccountDetail,
    arguments: const AppRouteArguments(entityId: '1100919408'),
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(accounts),
      featureAvailabilityProvider(
        FeatureCapability.coreAccountActivity,
      ).overrideWithValue(FeatureAvailability.available),
      featureAvailabilityProvider(
        FeatureCapability.coreAccountHistory,
      ).overrideWithValue(FeatureAvailability.available),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('account detail shows the live summary', (tester) async {
    await _pumpDetail(tester, const _Accounts());

    expect(find.text('Boc Flex'), findsWidgets);
    expect(find.text('₦7,654.30'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
  });

  // Rows have no confirmed schema, so none of their values are shown.
  testWidgets('unmapped history says activity exists without rows', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      const _Accounts([
        {'Narration': 'GUESSED ROW'},
      ]),
    );

    expect(
      find.text(
        "You have activity in this period. Details aren't available in the "
        'app yet.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('GUESSED ROW'), findsNothing);
  });

  testWidgets('empty history is not shown as activity', (tester) async {
    await _pumpDetail(tester, const _Accounts());

    expect(find.text('No transactions in this period.'), findsOneWidget);
  });
}
