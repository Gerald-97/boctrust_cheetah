import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_models.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/core_transaction_limit_service.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Limits extends CoreTransactionLimitService {
  const _Limits(this.reply) : super(null);
  final NotifierState<TransactionLimits> reply;

  @override
  Future<NotifierState<TransactionLimits>> getLimits() async => reply;
}

/// The User Service's tier 0: BVN and liveness not yet verified.
class _Tier0 extends LayoutTiers {
  @override
  NotifierState<UserTierInfoData> build() {
    final tiers = super.build().data!;
    return NotifierState.done(
      UserTierInfoData(
        userId: tiers.userId,
        currentTier: 0,
        currentTierSummary: tiers.currentTierSummary,
        tiers: tiers.tiers,
      ),
    );
  }
}

const _coreRefusal = NotifierState<TransactionLimits>.error(
  'You need to complete at least Tier 1 verification (BVN and a liveness '
  'selfie) before you can transact.',
  statusCode: 403,
);

Future<void> _open(
  WidgetTester tester,
  NotifierState<TransactionLimits> reply, {
  String route = AppRoutes.transactionLimits,
  UserTierNotifier Function() tiers = LayoutTiers.new,
}) async {
  await pumpFlow(
    tester,
    route: route,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      userTierProvider.overrideWith(tiers),
      kycStatusProvider.overrideWith(LayoutKyc.new),
      coreTransactionLimitServiceProvider.overrideWithValue(_Limits(reply)),
      featureAvailabilityProvider(
        FeatureCapability.transactionLimitsView,
      ).overrideWithValue(FeatureAvailability.available),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // The ceilings are documented in Kobo; custom and effective values are
  // compared with them, so they share the unit.
  test('reads Kobo limits as Naira, with no custom value unset', () {
    final limits = TransactionLimits.fromJson({
      'tier': 2,
      'businessSingleTransferLimit': '50000000',
      'businessSingleBillPaymentLimit': '10000000',
      'businessDailyTransferLimit': '200000000',
      'customSingleTransferLimit': '2000000',
      'customSingleBillPaymentLimit': null,
      'effectiveSingleTransferLimit': '2000000',
      'effectiveSingleBillPaymentLimit': '10000000',
      'effectiveDailyTransferLimit': '200000000',
    });

    expect(limits.tier, 2);
    expect(limits.singleTransfer.effective, '20000.00');
    expect(limits.singleTransfer.business, '500000.00');
    expect(limits.singleTransfer.custom, '20000.00');
    expect(limits.singleBillPayment.custom, isNull);
    expect(limits.dailyTransfer.effective, '2000000.00');
  });

  testWidgets('shows the effective limits', (tester) async {
    await _open(
      tester,
      NotifierState.done(
        TransactionLimits.fromJson({
          'tier': 1,
          'businessSingleTransferLimit': '5000000',
          'businessSingleBillPaymentLimit': '1000000',
          'businessDailyTransferLimit': '20000000',
          'effectiveSingleTransferLimit': '5000000',
          'effectiveSingleBillPaymentLimit': '1000000',
          'effectiveDailyTransferLimit': '20000000',
        }),
      ),
    );

    expect(find.text('₦50,000.00'), findsOneWidget);
    expect(find.text('₦200,000.00'), findsOneWidget);
  });

  testWidgets('tier 0 is sent to verification, not shown zero limits', (
    tester,
  ) async {
    await _open(tester, _coreRefusal, tiers: _Tier0.new);

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Verify now'), findsOneWidget);
    expect(find.textContaining('₦'), findsNothing);
  });

  // Staging, 10 October: Core refused a customer the User Service reports
  // as Tier 1 with BVN and liveness verified.
  testWidgets('a verified customer refused by Core sees its reason', (
    tester,
  ) async {
    await _open(tester, _coreRefusal);

    expect(find.text(_coreRefusal.message!), findsOneWidget);
    expect(find.text('Verify now'), findsNothing);
    expect(find.textContaining('₦'), findsNothing);
  });

  testWidgets('the tier overview links to the limits', (tester) async {
    await _open(tester, _coreRefusal, route: AppRoutes.tierOverview);

    await tester.scrollUntilVisible(find.text('View transaction limits'), 200);
    await tester.tap(find.text('View transaction limits'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(find.text(_coreRefusal.message!), findsOneWidget);
  });
}
