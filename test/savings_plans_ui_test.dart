import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/savings/model/savings_plan_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_savings_plan_service.dart';
import 'package:flutter/material.dart'
    show LinearProgressIndicator, PopupMenuButton, Size, TextField;
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

/// New plans can start above their target, as Core funds the product minimum.
const _aboveTarget = _Plans(
  detail: NotifierState.done(
    SavingsPlanDetail(
      plan: SavingsPlan(
        id: 'p1',
        type: SavingsProductType.smartSave,
        name: 'Rent',
        principal: '5000.00',
        target: '4500.00',
        status: SavingsPlanStatus.active,
        accruedInterest: '0.00',
      ),
      events: [
        SavingsPlanEvent(type: SavingsPlanEventType.topUp, amount: '5000.00'),
        SavingsPlanEvent(type: SavingsPlanEventType.created, amount: '0.00'),
      ],
    ),
  ),
);

class _HiddenBalances extends HomeBalanceHiddenNotifier {
  @override
  bool build() => true;
}

final _funded = <(String, String)>[];
final _opened = <String>[];
final _createdRequests = <CreateSavingsPlanRequest>[];

class _Plans extends CoreSavingsPlanService {
  const _Plans({this.detail, this.created = const NotifierState.done('p9')})
    : super(null);
  final NotifierState<SavingsPlanDetail>? detail;
  final NotifierState<String> created;

  @override
  Future<NotifierState<String>> createPlan(
    CreateSavingsPlanRequest request,
  ) async {
    _createdRequests.add(request);
    return created;
  }

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
  Future<NotifierState<SavingsPlanActionResult>> liquidatePlan(
    String planId,
  ) async => NotifierState.done(
    SavingsPlanActionResult(
      planId: planId,
      status: SavingsPlanStatus.liquidated,
      amountPaidOut: '5117.40',
      interestAccrued: '120.40',
      earlyWithdrawalFee: '3.01',
      interestPending: '0.00',
    ),
  );

  @override
  Future<NotifierState<SavingsPlanDetail>> getPlan(String planId) async {
    _opened.add(planId);
    return detail ??
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
}

class _FixedPlans extends _Plans {
  const _FixedPlans();

  @override
  Future<NotifierState<List<SavingsProductGroup>>> getPlans(
    SavingsProductType product,
  ) async => const NotifierState.done([
    SavingsProductGroup(
      type: SavingsProductType.fixed,
      productName: 'Boc Fixed Deposit',
      accountNumber: '0000000003',
      plans: [],
    ),
  ]);
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
  bool create = false,
  bool hidden = false,
}) async {
  // Tall enough that the detail's activity rows are built, not lazily skipped.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1600);
  addTearDown(tester.view.reset);
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
      if (create)
        featureAvailabilityProvider(
          FeatureCapability.smartSaveCreate,
        ).overrideWithValue(FeatureAvailability.available),
      if (create)
        featureAvailabilityProvider(
          FeatureCapability.fixedDepositCreate,
        ).overrideWithValue(FeatureAvailability.available),
      if (hidden) homeBalanceHiddenProvider.overrideWith(_HiddenBalances.new),
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
    expect(find.textContaining('Account ••••'), findsNothing);

    await tester.tap(find.text('Rent'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Top-up'), findsOneWidget);
    expect(find.text('+₦2,500.00'), findsOneWidget);
  });

  testWidgets('a product with plans still offers another', (tester) async {
    await _open(tester, AppRoutes.targetSave, const _Plans(), create: true);

    final balanceY = tester.getTopLeft(find.text('Available balance')).dy;
    final buttonY = tester.getTopLeft(find.text('Create a new goal')).dy;
    final goalsY = tester.getTopLeft(find.text('Your goals (1)')).dy;
    expect(balanceY, lessThan(buttonY));
    expect(buttonY, lessThan(goalsY));

    await tester.tap(find.text('Create a new goal'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('What are you saving for?'), findsOneWidget);
  });

  testWidgets('an empty deposit account offers creation below its balance', (
    tester,
  ) async {
    await _open(tester, AppRoutes.lockSave, const _FixedPlans(), create: true);

    expect(find.textContaining('Account ••••'), findsNothing);
    expect(find.text('Create a new deposit'), findsOneWidget);
    await tester.tap(find.text('Create a new deposit'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Choose a term'), findsOneWidget);
  });

  testWidgets('a plan above its target says so', (tester) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      _aboveTarget,
      arguments: const AppRouteArguments(entityId: 'p1'),
    );

    expect(find.text('Target reached'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('+₦5,000.00'), findsOneWidget);
    expect(find.text('Interest so far'), findsOneWidget);
    // Interest only: the created row has no amount.
    expect(find.text('₦0.00'), findsOneWidget);
  });

  testWidgets('hidden balances hide the amounts and the progress', (
    tester,
  ) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      _aboveTarget,
      arguments: const AppRouteArguments(entityId: 'p1'),
      hidden: true,
    );

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('5,000'), findsNothing);
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

  testWidgets('withdrawing early shows what was paid', (tester) async {
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(),
      arguments: const AppRouteArguments(entityId: 'p1'),
      withdraw: true,
    );

    tester
        .widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>))
        .onSelected!('withdraw');
    // Let the confirm sheet finish sliding up before tapping it.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Withdraw early'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Withdrawn'), findsOneWidget);
    expect(find.text('Paid to Boc Flex'), findsOneWidget);
    expect(find.text('₦5,117.40'), findsOneWidget);
    expect(find.text('Early withdrawal fee'), findsOneWidget);
    expect(find.text('₦3.01'), findsOneWidget);
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
    expect(find.text('₦2,500.00'), findsOneWidget);
    expect(find.text('New plan balance'), findsOneWidget);
    expect(find.text('₦7,500.00'), findsOneWidget);
  });

  testWidgets('the deposit result fits large text', (tester) async {
    _funded.clear();
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
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

    expect(find.text('New plan balance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hidden balance stays hidden after a deposit', (tester) async {
    _funded.clear();
    await _open(
      tester,
      AppRoutes.savingsPlanDetail,
      const _Plans(),
      arguments: const AppRouteArguments(entityId: 'p1'),
      deposit: true,
      hidden: true,
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

    expect(find.text('Money added'), findsOneWidget);
    expect(find.textContaining('7,500'), findsNothing);
    expect(find.textContaining('2,500.00'), findsNothing);
  });

  /// Fills the SmartSave wizard up to its confirm step.
  Future<void> walkGoalWizard(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(0), 'Rent');
    await tester.enterText(find.byType(TextField).at(1), '200,000');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('6 months'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
  }

  testWidgets('goal target must be above the opening minimum', (tester) async {
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(),
      create: true,
    );

    await tester.enterText(find.byType(TextField).at(0), 'Rent');
    await tester.enterText(find.byType(TextField).at(1), '5,000');
    await tester.pump();
    expect(find.text('Target amount must be above ₦5,000.00.'), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField).at(1), '5,000.01');
    await tester.pump();
    expect(find.text('Target amount must be above ₦5,000.00.'), findsNothing);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a goal name accepts emoji and keeps it in the review', (
    tester,
  ) async {
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(),
      create: true,
    );

    await tester.enterText(find.byType(TextField).at(0), 'New home 🏡');
    await tester.enterText(find.byType(TextField).at(1), '200,000');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('6 months'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('New home 🏡'), findsOneWidget);
  });

  testWidgets('creating a goal opens the new plan', (tester) async {
    _opened.clear();
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(),
      create: true,
    );

    await walkGoalWizard(tester);
    await tester.tap(find.text('Create goal'));
    await tester.pump();
    expect(find.text('Confirm opening transfer'), findsOneWidget);
    await tester.tap(find.text('Confirm and create'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(_opened, ['p9']);
    expect(find.text('Create goal'), findsNothing);
  });

  testWidgets('the goal review explains manual saving and funding', (
    tester,
  ) async {
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(),
      create: true,
    );

    await walkGoalWizard(tester);

    expect(find.text('Review your goal'), findsOneWidget);
    expect(find.text('Saving plan'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('₦200,000.00'), findsOneWidget);
    expect(find.text('Manual deposits'), findsOneWidget);
    expect(find.text('₦5,000.00 from Boc Flex Savings'), findsOneWidget);
    expect(find.textContaining('minimum opening balance'), findsOneWidget);
  });

  testWidgets(
    'SmartSave shows its minimum and requires transfer confirmation',
    (tester) async {
      _createdRequests.clear();
      await _open(
        tester,
        AppRoutes.targetSaveCreate,
        const _Plans(),
        create: true,
      );

      expect(find.textContaining('₦5,000'), findsWidgets);
      await walkGoalWizard(tester);
      expect(find.textContaining('₦5,000'), findsWidgets);
      await tester.tap(find.text('Create goal'));
      await tester.pump();

      expect(_createdRequests, isEmpty);
      expect(find.text('Confirm opening transfer'), findsOneWidget);
      expect(find.textContaining('₦5,000'), findsWidgets);
      expect(find.textContaining('Boc Flex Savings'), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(_createdRequests, isEmpty);
      expect(find.text('Review your goal'), findsOneWidget);
    },
  );

  testWidgets('Fixed Deposit shows its minimum and confirms funding', (
    tester,
  ) async {
    _createdRequests.clear();
    await _open(tester, AppRoutes.lockCreate, const _Plans(), create: true);

    expect(find.textContaining('₦1,000'), findsWidgets);
    await tester.tap(find.text('3 months'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('Review your deposit'), findsOneWidget);
    expect(find.text('Deposit details'), findsOneWidget);
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('Term'), findsNothing);
    expect(find.textContaining('₦1,000'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'School fees 🎓');
    await tester.pump();
    await tester.tap(find.text('Create deposit'));
    await tester.pump();

    expect(_createdRequests, isEmpty);
    expect(find.text('Confirm opening transfer'), findsOneWidget);
    expect(find.text('School fees 🎓'), findsWidgets);
    expect(find.textContaining('₦1,000'), findsWidgets);
    await tester.tap(find.text('Confirm and create'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_createdRequests, hasLength(1));
    expect(_createdRequests.single.planName, 'School fees 🎓');
  });

  testWidgets('Fixed Deposit accepts a custom date from day 30', (
    tester,
  ) async {
    await _open(tester, AppRoutes.lockCreate, const _Plans(), create: true);

    expect(find.textContaining('30 days from today'), findsOneWidget);
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Review your deposit'), findsOneWidget);
    expect(find.text('30 days'), findsOneWidget);
    expect(find.text('Target maturity date'), findsOneWidget);
  });

  testWidgets('SmartSave accepts a custom date from day 90', (tester) async {
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(),
      create: true,
    );
    await tester.enterText(find.byType(TextField).at(0), 'Rent');
    await tester.enterText(find.byType(TextField).at(1), '200,000');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.textContaining('90 days from today'), findsOneWidget);
    await tester.tap(find.text('Choose a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Review your goal'), findsOneWidget);
    expect(find.text('90 days'), findsOneWidget);
    expect(find.text('Target maturity date'), findsOneWidget);
  });

  testWidgets('insufficient Boc Flex funds opens an error dialog', (
    tester,
  ) async {
    _createdRequests.clear();
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(
        created: NotifierState.error('Insufficient balance', statusCode: 400),
      ),
      create: true,
    );

    await walkGoalWizard(tester);
    await tester.tap(find.text('Create goal'));
    await tester.pump();
    await tester.tap(find.text('Confirm and create'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_createdRequests, hasLength(1));
    expect(find.text('Not enough in Boc Flex'), findsOneWidget);
    expect(find.textContaining('₦5,000'), findsWidgets);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(find.text('Review your goal'), findsOneWidget);
  });

  testWidgets('Fixed Deposit insufficient funds names its minimum', (
    tester,
  ) async {
    await _open(
      tester,
      AppRoutes.lockCreate,
      const _Plans(
        created: NotifierState.error('Insufficient funds', statusCode: 400),
      ),
      create: true,
    );

    await tester.tap(find.text('3 months'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Create deposit'));
    await tester.pump();
    await tester.tap(find.text('Confirm and create'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Not enough in Boc Flex'), findsOneWidget);
    expect(find.textContaining('₦1,000'), findsWidgets);
  });

  testWidgets('a term Core does not offer keeps the draft', (tester) async {
    await _open(
      tester,
      AppRoutes.targetSaveCreate,
      const _Plans(
        created: NotifierState.error(
          'No rate for this tenor.',
          statusCode: 400,
        ),
      ),
      create: true,
    );

    await walkGoalWizard(tester);
    await tester.tap(find.text('Create goal'));
    await tester.pump();
    await tester.tap(find.text('Confirm and create'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text('Could not create goal'), findsOneWidget);
    expect(find.text('No rate for this tenor.'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(find.text('Create goal'), findsOneWidget);
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
