import 'package:flutter/widgets.dart';
import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_models.dart';
import 'package:boctrust_savings_loan/module/account/model/transaction_limit_update_models.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/core_transaction_limit_service.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _Limits extends CoreTransactionLimitService {
  _Limits(this.reply) : super(null);
  final NotifierState<TransactionLimits> reply;
  final drafts = <TransactionLimitDraft>[];
  var finalized = 0;

  @override
  Future<NotifierState<TransactionLimits>> getLimits() async => reply;

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateLimitUpdate(
    TransactionLimitDraft draft,
  ) async {
    drafts.add(draft);
    return NotifierState.done(
      CoreTransferInitiation(
        reference: 'a1b2c3d4e5f6',
        checks: const {CoreTransferCheck.pin, CoreTransferCheck.otp},
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
      ),
    );
  }

  @override
  Future<NotifierState<CoreCheckProgress>> verifyLimitPin(
    String reference,
    String pin,
  ) async => const NotifierState.done(
    CoreCheckProgress(pending: {CoreTransferCheck.otp}, otpSent: true),
  );

  @override
  Future<NotifierState<CoreCheckProgress>> verifyLimitOtp(
    String reference,
    String otp,
  ) async => const NotifierState.done(CoreCheckProgress());

  @override
  Future<NotifierState<bool>> finalizeLimitUpdate(String reference) async {
    finalized++;
    return const NotifierState.done(true);
  }
}

/// Tier 1: ₦50,000 single transfer, ₦200,000 a day, ₦10,000 per bill.
final _tier1 = NotifierState.done(
  TransactionLimits.fromJson({
    'tier': 1,
    'businessSingleTransferLimit': '50000.00',
    'businessSingleBillPaymentLimit': '10000.00',
    'businessDailyTransferLimit': '200000.00',
    'effectiveSingleTransferLimit': '50000.00',
    'effectiveSingleBillPaymentLimit': '10000.00',
    'effectiveDailyTransferLimit': '200000.00',
  }),
);

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
  _Limits? limits,
  bool editable = false,
}) async {
  await pumpFlow(
    tester,
    route: route,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      userTierProvider.overrideWith(tiers),
      kycStatusProvider.overrideWith(LayoutKyc.new),
      coreTransactionLimitServiceProvider.overrideWithValue(
        limits ?? _Limits(reply),
      ),
      featureAvailabilityProvider(
        FeatureCapability.transactionLimitsView,
      ).overrideWithValue(FeatureAvailability.available),
      featureAvailabilityProvider(
        FeatureCapability.transactionLimitsEdit,
      ).overrideWithValue(
        editable
            ? FeatureAvailability.available
            : FeatureAvailability.unavailable,
      ),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('reads Naira limits, with no custom value unset', () {
    final limits = TransactionLimits.fromJson({
      'tier': 2,
      'businessSingleTransferLimit': '500000.00',
      'businessSingleBillPaymentLimit': '100000.00',
      'businessDailyTransferLimit': '2000000',
      'customSingleTransferLimit': '20000.00',
      'customSingleBillPaymentLimit': null,
      'effectiveSingleTransferLimit': '20000.00',
      'effectiveSingleBillPaymentLimit': '100000.00',
      'effectiveDailyTransferLimit': '2000000',
    });

    expect(limits.tier, 2);
    expect(limits.singleTransfer.effective, '20000.00');
    expect(limits.singleTransfer.business, '500000.00');
    expect(limits.singleTransfer.custom, '20000.00');
    expect(limits.singleBillPayment.custom, isNull);
    expect(limits.dailyTransfer.effective, '2000000');
  });

  testWidgets('shows the effective limits', (tester) async {
    await _open(
      tester,
      NotifierState.done(
        TransactionLimits.fromJson({
          'tier': 1,
          'businessSingleTransferLimit': '50000.00',
          'businessSingleBillPaymentLimit': '10000.00',
          'businessDailyTransferLimit': '200000.00',
          'effectiveSingleTransferLimit': '50000.00',
          'effectiveSingleBillPaymentLimit': '10000.00',
          'effectiveDailyTransferLimit': '200000.00',
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

  group('changing limits', () {
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> edit(WidgetTester tester, String field, String text) async {
      await tester.enterText(find.widgetWithText(AppTextField, field), text);
      await tester.pump();
    }

    testWidgets('needs its own capability', (tester) async {
      await _open(tester, _tier1);

      expect(find.text('₦200,000.00'), findsOneWidget);
      expect(find.text('Change limits'), findsNothing);
    });

    testWidgets('a changed limit is verified by PIN and OTP, then shown', (
      tester,
    ) async {
      final limits = _Limits(_tier1);
      await _open(tester, _tier1, limits: limits, editable: true);

      await tester.tap(find.text('Change limits'));
      await settle(tester);
      await edit(tester, 'Daily transfers (₦)', '1,000');
      await tester.tap(find.text('Review changes'));
      await settle(tester);
      expect(find.text('₦1,000.00'), findsOneWidget);

      await tester.tap(find.text('Confirm changes'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).last, '0007');
      await tester.pump();
      await tester.tap(find.text('Verify PIN'));
      await settle(tester);
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.tap(find.text('Verify code'));
      await settle(tester);

      // Only the changed limit, in Naira.
      expect(limits.drafts, [
        const TransactionLimitDraft(dailyTransferLimit: '1000.00'),
      ]);
      expect(limits.finalized, 1);
      expect(find.text('Your limits were updated.'), findsOneWidget);
    });

    testWidgets('a limit above the tier maximum is never sent', (tester) async {
      final limits = _Limits(_tier1);
      await _open(tester, _tier1, limits: limits, editable: true);

      await tester.tap(find.text('Change limits'));
      await settle(tester);
      await edit(tester, 'Daily transfers (₦)', '300,000');
      await tester.tap(find.text('Review changes'), warnIfMissed: false);
      await settle(tester);

      expect(find.textContaining('above your tier maximum'), findsOneWidget);
      expect(find.text('Confirm changes'), findsNothing);
      expect(limits.drafts, isEmpty);
    });

    testWidgets('an unchanged form sends nothing', (tester) async {
      final limits = _Limits(_tier1);
      await _open(tester, _tier1, limits: limits, editable: true);

      await tester.tap(find.text('Change limits'));
      await settle(tester);
      await tester.tap(find.text('Review changes'), warnIfMissed: false);
      await settle(tester);

      expect(find.text('Confirm changes'), findsNothing);
      expect(limits.drafts, isEmpty);
    });
  });
}
