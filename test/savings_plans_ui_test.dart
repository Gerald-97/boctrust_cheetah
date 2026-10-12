import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/savings/model/savings_plan_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_savings_plan_service.dart';
import 'package:flutter/material.dart' show PopupMenuButton, TextField;
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

const _plan = SavingsPlan(
  id: 'p1',
  type: SavingsProductType.smartSave,
  name: 'Rent',
  principal: '5000.00',
  status: SavingsPlanStatus.active,
);

final _funded = <(String, String)>[];

class _Plans extends CoreSavingsPlanService {
  const _Plans({this.detail}) : super(null);
  final NotifierState<SavingsPlanDetail>? detail;

  @override
  Future<NotifierState<List<SavingsProductGroup>>> getPlans(
    SavingsProductType product,
  ) async => const NotifierState.done([
    SavingsProductGroup(
      type: SavingsProductType.smartSave,
      productName: 'Boc SmartSave',
      accountNumber: '0000000002',
      plans: [_plan],
    ),
  ]);

  @override
  Future<NotifierState<SavingsPlanActionResult>> fundPlan(
    String planId,
    String amountNaira,
  ) async {
    _funded.add((planId, amountNaira));
    return NotifierState.done(
      SavingsPlanActionResult(
        planId: planId,
        status: SavingsPlanStatus.active,
        principalAmount: '7500.00',
      ),
    );
  }

  @override
  Future<NotifierState<SavingsPlanDetail>> getPlan(String planId) async =>
      detail ??
      NotifierState.done(
        SavingsPlanDetail(
          plan: _plan,
          events: [
            SavingsPlanEvent(
              type: SavingsPlanEventType.topUp,
              amount: '2500.00',
              createdAt: DateTime.utc(2026, 10, 9),
            ),
          ],
        ),
      );
}

/// Flex plus the SmartSave account Core opened with the first plan.
class _SmartSaveAccounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'products': [
        for (final (code, name, number) in [
          (kFlexProductCode, 'Boc Flex', '0000000001'),
          ('bocSmartSave', 'Boc SmartSave', '0000000002'),
        ])
          {
            'productCode': code,
            'productName': name,
            'accountNumber': number,
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
  String route,
  _Plans plans, {
  AppRouteArguments arguments = const AppRouteArguments(),
  bool withdraw = false,
  bool deposit = false,
}) async {
  await pumpFlow(
    tester,
    route: route,
    arguments: arguments,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      coreSavingsPlanServiceProvider.overrideWithValue(plans),
      featureAvailabilityProvider(
        FeatureCapability.savingsPlansView,
      ).overrideWithValue(FeatureAvailability.available),
      if (withdraw)
        featureAvailabilityProvider(
          FeatureCapability.savingsPlanWithdraw,
        ).overrideWithValue(FeatureAvailability.available),
      if (deposit)
        featureAvailabilityProvider(
          FeatureCapability.savingsPlanDeposit,
        ).overrideWithValue(FeatureAvailability.available),
      userHomeProvider.overrideWith(LayoutHome.new),
      customerBankAccountsProvider.overrideWith(_SmartSaveAccounts.new),
      coreBankProductsProvider.overrideWith(LayoutCoreProducts.new),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('SmartSave lists server plans and opens one', (tester) async {
    await _open(tester, AppRoutes.targetSave, const _Plans());

    // The product balance is the account's, as the account list reports it.
    expect(find.text('₦125.00'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);

    await tester.tap(find.text('Rent'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Top-up'), findsOneWidget);
    expect(find.text('₦2,500.00'), findsOneWidget);
  });

  testWidgets('plan detail shows interest so far', (tester) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(
        detail: NotifierState.done(
          SavingsPlanDetail(
            plan: SavingsPlan(
              id: 'p1',
              type: SavingsProductType.smartSave,
              name: 'Rent',
              principal: '5000.00',
              status: SavingsPlanStatus.active,
              accruedInterest: '120.40',
            ),
            events: [],
          ),
        ),
      ),
      arguments: const AppRouteArguments(entityId: 'p1'),
    );

    expect(find.text('Interest so far'), findsOneWidget);
    expect(find.text('₦120.40'), findsOneWidget);
  });

  testWidgets('early withdrawal names the fee on the interest', (tester) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(
        detail: NotifierState.done(
          SavingsPlanDetail(
            plan: SavingsPlan(
              id: 'p1',
              type: SavingsProductType.smartSave,
              name: 'Rent',
              principal: '5000.00',
              status: SavingsPlanStatus.active,
              earlyWithdrawalFeePercent: '2.5',
            ),
            events: [],
          ),
        ),
      ),
      arguments: const AppRouteArguments(entityId: 'p1'),
      withdraw: true,
    );

    // The menu's own overlay is not hit-testable in the harness, so choose
    // the item the way the menu does.
    tester
        .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
        .onSelected!('withdraw');
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('minus a 2.5% early withdrawal fee'),
      findsOneWidget,
    );
    expect(find.text('Withdraw early'), findsOneWidget);
  });

  testWidgets('depositing into a plan sends the typed amount', (tester) async {
    _funded.clear();
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(),
      arguments: const AppRouteArguments(entityId: 'p1'),
      deposit: true,
    );

    await tester.tap(find.text('Deposit'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.enterText(find.byType(TextField), '2,500');
    await tester.pump();
    await tester.tap(find.text('Add money'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(_funded, [('p1', '2500.00')]);
    expect(find.text('Money added'), findsOneWidget);
  });

  testWidgets('a plan the customer no longer has says so', (tester) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(detail: NotifierState.error('Not found.', statusCode: 404)),
      arguments: const AppRouteArguments(entityId: 'p1'),
    );

    expect(find.text('This plan is no longer available.'), findsOneWidget);
  });

  testWidgets('an owned SmartSave account opens its plans', (tester) async {
    await _open(tester, AppRoutes.savingsHub, const _Plans());

    await tester.tap(find.text('Boc SmartSave'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Rent'), findsOneWidget);
  });
}
