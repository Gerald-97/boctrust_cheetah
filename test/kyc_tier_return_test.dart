import 'dart:async';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/service/home_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_camera_permission.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_config.dart';
import 'package:boctrust_savings_loan/module/kyc/screens/dojah_webview.dart';
import 'package:boctrust_savings_loan/module/kyc/service/dojah_platform_route.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kyc_configuration_fixtures.dart';
import 'support/flow_harness.dart';

Map<String, Object?> _limit(String display) => {
  'value': null,
  'isUnlimited': false,
  'displayValue': display,
};

Map<String, Object?> _tierCard(int tier, String status) => {
  'tier': tier,
  'title': 'Tier $tier',
  'description': 'Tier $tier description.',
  'requirements': [
    {'key': 'bvn', 'label': 'BVN or NIN', 'isSatisfied': false},
  ],
  'status': status,
  'statusLabel': status == 'verified' ? 'Verified' : 'In progress',
  'actionLabel': 'Continue',
  'lockReason': null,
  'singleTransactionLimit': _limit('₦50,000'),
  'singleDepositLimit': _limit('₦50,000'),
  'cumulativeBalanceLimit': _limit('₦300,000'),
  'checkLists': <String>[],
};

UserTierInfoData _tiers({int currentTier = 0}) => UserTierInfoData.fromJson({
  'userId': 'user-1',
  'currentTier': currentTier,
  'currentTierSummary': {
    'tier': currentTier,
    'tierLabel': 'Tier $currentTier',
    'dailyTransferLimit': _limit('₦0'),
    'maxWalletBalance': _limit('₦0'),
  },
  'tiers': [_tierCard(1, 'in_progress'), _tierCard(2, 'in_progress')],
});

KycStatusData _notStarted() => KycStatusData.fromJson({
  'userId': 'user-1',
  'tier': 0,
  'identity': {'status': 'not_started'},
  'governmentId': {'status': 'not_started'},
  'utilityBill': {'status': 'not_started'},
  'nextAction': 'verify_identity',
});

KycInitiationData _dojahIdentity() => KycInitiationData.fromJson({
  'verificationId': 'kiv-1',
  'provider': 'dojah',
  'environment': 'live',
  'identityType': 'bvn',
  'identityLast4': '8901',
  'country': 'NG',
  'contractVersion': 2,
  'attemptId': 'attempt-1',
  'operation': 'identity',
  'referenceId': 'dojah-ref-1',
  'launchExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
});

KycInitiationData _dojahGovernmentId() => KycInitiationData.fromJson({
  'verificationId': 'kiv-2',
  'provider': 'dojah',
  'environment': 'live',
  'documentType': 'voter_id',
  'country': 'NG',
  'contractVersion': 2,
  'attemptId': 'attempt-2',
  'operation': 'government_id',
  'referenceId': 'dojah-ref-2',
  'launchExpiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(minutes: 10))
      .toIso8601String(),
});

class _Kyc extends KycService with KycConfigurationFixture {
  _Kyc() : super(ApiService(Dio()));

  var statusCalls = 0;

  @override
  Future<NotifierState<KycStatusData>> getStatus() async {
    statusCalls++;
    return NotifierState.done(_notStarted());
  }

  @override
  Future<NotifierState<KycInitiationData>> initiateIdentity(
    IdentityVerificationRequest request,
  ) async => NotifierState.done(_dojahIdentity());

  @override
  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) async => NotifierState.done(_dojahGovernmentId());
}

class _Users extends UserService {
  _Users({UserTierInfoData? tiers})
    : _tiersData = tiers ?? _tiers(),
      super(ApiService(Dio()));

  var tierCalls = 0;
  final UserTierInfoData _tiersData;

  @override
  Future<NotifierState<UserOwnProfileData>> getOwnProfile() async =>
      NotifierState.done(
        UserOwnProfileData.fromJson(const {
          'userId': 'user-1',
          'email': 'person@example.test',
          'phoneNumber': '+2348012345678',
          'tier': 1,
          'status': 'active',
          'transactionStatus': 'active',
          'isVerifiedAccount': true,
          'isVerifiedEmail': true,
          'isVerifiedPhoneNumber': true,
          'isCreatedPassword': true,
          'isCreatedPin': true,
        }),
      );

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async {
    tierCalls++;
    return NotifierState.done(_tiersData);
  }
}

class _Home extends HomeService {
  _Home() : super(ApiService(Dio()));

  @override
  Future<NotifierState<UserHomeData>> getOwnHome() async =>
      const NotifierState.error('stub');
}

/// Stands in for the embedded browser, reporting [outcome] as soon as the
/// capture route builds it.
class _Gateway {
  _Gateway(this.outcome);

  final KycCaptureOutcome outcome;
  var calls = 0;
  Uri? uri;

  Widget build({
    required Uri uri,
    required ValueChanged<KycCaptureOutcome> onFinished,
  }) {
    calls++;
    this.uri = uri;
    scheduleMicrotask(() => onFinished(outcome));
    return const Text('Dojah browser');
  }
}

void main() {
  late _Users users;
  late _Kyc kyc;

  Future<void> mountFlow(
    WidgetTester tester, {
    required _Gateway gateway,
    required String route,
    UserTierInfoData? tiers,
  }) async {
    users = _Users(tiers: tiers);
    kyc = _Kyc();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      ),
    );

    await pumpFlow(
      tester,
      route: route,
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        userServiceProvider.overrideWithValue(users),
        homeServiceProvider.overrideWithValue(_Home()),
        dojahWebViewBuilderProvider.overrideWithValue(gateway.build),
        dojahCameraPermissionProvider.overrideWithValue(() async => true),
        dojahPlatformRouteProvider.overrideWithValue(
          DojahPlatformRoute.webView,
        ),
        dojahConfigProvider.overrideWithValue(
          const DojahConfig(
            selfieWidgetId: 'selfie-widget',
            governmentWidgetId: 'government-widget',
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  /// Opens the step [tier]'s card from the tier list.
  Future<void> openTierCard(WidgetTester tester, int tier) async {
    expect(find.text('Account tiers'), findsOneWidget);
    await tapAndSettle(tester, find.text('Tier $tier'));
  }

  /// Drains the toast plugin's own timer so it does not outlive the tree.
  Future<void> settleToast(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  testWidgets('the matching tier card is marked as the current tier', (
    tester,
  ) async {
    await mountFlow(
      tester,
      gateway: _Gateway(KycCaptureOutcome.cancelled),
      route: '/account/tier',
      tiers: _tiers(currentTier: 1),
    );

    final tierOneCard = find.byWidgetPredicate(
      (widget) => widget is TierCard && widget.tier == 1,
    );
    expect(
      find.descendant(of: tierOneCard, matching: find.text('Current tier')),
      findsOneWidget,
    );
    expect(find.text('Current tier'), findsOneWidget);
    expect(tester.getSemantics(tierOneCard).label, contains('Current tier'));
  });

  Future<void> runIdentityCapture(
    WidgetTester tester, {
    required _Gateway gateway,
    String route = '/account/tier',
  }) async {
    await mountFlow(tester, gateway: gateway, route: route);
    if (route == '/account/tier') await openTierCard(tester, 1);
    expect(find.text('Identity verification'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('identity-number')),
      '12345678901',
    );
    await tapAndSettle(tester, find.byKey(const ValueKey('identity-submit')));
    await tapAndSettle(tester, find.text('I agree'));
    await settleToast(tester);
  }

  Future<void> runGovernmentIdCapture(
    WidgetTester tester, {
    required _Gateway gateway,
    String route = '/account/tier',
  }) async {
    await mountFlow(tester, gateway: gateway, route: route);
    if (route == '/account/tier') await openTierCard(tester, 2);
    expect(find.text('Government ID'), findsWidgets);

    // The first catalogue document needs no number.
    await tapAndSettle(tester, find.text('Start verification'));
    await settleToast(tester);
  }

  testWidgets(
    'a submitted BVN capture returns to the tier list and reloads it',
    (tester) async {
      final gateway = _Gateway(KycCaptureOutcome.submitted);
      await runIdentityCapture(tester, gateway: gateway);

      expect(gateway.calls, 1);
      expect(find.text('Account tiers'), findsOneWidget);
      expect(find.text('Identity verification'), findsNothing);
      // The list the user lands on is reloaded, not the one they left.
      expect(users.tierCalls, greaterThan(1));
      expect(kyc.statusCalls, greaterThan(1));
    },
  );

  testWidgets('a deep-linked BVN screen also lands on the tier list', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.submitted);
    await runIdentityCapture(
      tester,
      gateway: gateway,
      route: '/account/tier/bvn',
    );

    expect(find.text('Account tiers'), findsOneWidget);
    expect(find.text('Identity verification'), findsNothing);
    expect(users.tierCalls, greaterThan(0));
  });

  testWidgets('a submitted document returns to the tier list and reloads it', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.submitted);
    await runGovernmentIdCapture(tester, gateway: gateway);

    expect(gateway.calls, 1);
    expect(find.text('Account tiers'), findsOneWidget);
    expect(find.text('Government ID'), findsNothing);
    expect(users.tierCalls, greaterThan(1));
    expect(kyc.statusCalls, greaterThan(1));
  });

  testWidgets('a deep-linked document screen also lands on the tier list', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.submitted);
    await runGovernmentIdCapture(
      tester,
      gateway: gateway,
      route: '/account/tier/government-id',
    );

    expect(find.text('Account tiers'), findsOneWidget);
    expect(find.text('Government ID'), findsNothing);
    expect(users.tierCalls, greaterThan(0));
  });

  testWidgets('a cancelled document capture stays on the document screen', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.cancelled);
    await runGovernmentIdCapture(tester, gateway: gateway);

    expect(gateway.calls, 1);
    expect(find.text('Government ID'), findsWidgets);
    expect(find.text('Account tiers'), findsNothing);
  });

  testWidgets('a cancelled BVN capture stays on the identity screen', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.cancelled);
    await runIdentityCapture(tester, gateway: gateway);

    expect(gateway.calls, 1);
    expect(find.text('Identity verification'), findsOneWidget);
    expect(find.text('Account tiers'), findsNothing);
  });

  testWidgets('capture carries the signed-in email so Dojah stops asking', (
    tester,
  ) async {
    final gateway = _Gateway(KycCaptureOutcome.submitted);
    await runIdentityCapture(tester, gateway: gateway);

    expect(
      gateway.uri?.queryParameters['user_data[email]'],
      'person@example.test',
    );
  });
}
