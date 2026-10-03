import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kyc_configuration_fixtures.dart';
import 'support/flow_harness.dart';

/// The `governmentId` section as `GET /users/me/kyc/status` returns it.
KycStatusData _status(Map<String, Object?> governmentId) =>
    KycStatusData.fromJson({
      'userId': 'user-1',
      'tier': 1,
      'identity': {
        'status': 'success',
        'identityType': 'bvn',
        'identityLast4': '0008',
        'hasBvnOrNin': true,
        'hasLivenessSelfie': true,
      },
      'governmentId': governmentId,
      'utilityBill': {'status': 'not_started'},
      'nextAction': 'verify_government_id',
    });

class _Kyc extends KycService with KycConfigurationFixture {
  _Kyc(this.governmentId, {this.configFails = false})
    : super(ApiService(Dio()));

  final Map<String, Object?> governmentId;
  final bool configFails;
  final requests = <Map<String, Object?>>[];

  @override
  Future<NotifierState<KycStatusData>> getStatus() async =>
      NotifierState.done(_status(governmentId));

  @override
  Future<NotifierState<KycProviderConfigData>> getProviderConfig() async =>
      configFails
      ? const NotifierState.error('Unavailable')
      : super.getProviderConfig();

  @override
  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) async {
    requests.add(request.toJson());
    return const NotifierState.error('stop here');
  }
}

class _Users extends UserService {
  _Users() : super(ApiService(Dio()));

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      const NotifierState<UserTierInfoData>.error('stub');
}

Future<_Kyc> _pump(
  WidgetTester tester, {
  required Map<String, Object?> governmentId,
  bool configFails = false,
}) async {
  final kyc = _Kyc(governmentId, configFails: configFails);
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await pumpFlow(
    tester,
    route: '/account/tier/government-id',
    overrides: [
      kycServiceProvider.overrideWithValue(kyc),
      userServiceProvider.overrideWithValue(_Users()),
    ],
  );
  await tester.pumpAndSettle();
  return kyc;
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(
    find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the dropdown follows the live catalogue in server order', (
    tester,
  ) async {
    await _pump(tester, governmentId: {'status': 'not_started'});
    await tester.tap(
      find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
    );
    await tester.pumpAndSettle();

    final labels = [
      'International Passport',
      "Driver's License",
      "Voter's Card",
      'National ID',
      'NIN Slip',
    ];
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label).last).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(find.textContaining('national_id'), findsNothing);
  });

  testWidgets('a document that needs no number never sends one', (
    tester,
  ) async {
    final kyc = await _pump(tester, governmentId: {'status': 'not_started'});

    // Type a number for the NIN slip, then switch to NIN, which needs none.
    await _choose(tester, 'NIN Slip');
    await tester.enterText(
      find.byKey(const ValueKey('document-number')),
      '12345678901',
    );
    await _choose(tester, 'National ID');
    expect(find.byKey(const ValueKey('document-number')), findsNothing);

    await tester.tap(find.text('Start verification'));
    await tester.pumpAndSettle();

    expect(kyc.requests.single, {
      'documentType': 'national_id',
      'country': 'NG',
    });
  });

  testWidgets('a document that needs a number blocks without one', (
    tester,
  ) async {
    final kyc = await _pump(tester, governmentId: {'status': 'not_started'});
    await _choose(tester, 'NIN Slip');

    await tester.tap(find.text('Start verification'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter the document number'), findsOneWidget);
    expect(kyc.requests, isEmpty);
  });

  testWidgets('a configuration failure offers Retry instead of the form', (
    tester,
  ) async {
    await _pump(
      tester,
      governmentId: {'status': 'not_started'},
      configFails: true,
    );

    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Start verification'), findsNothing);
  });

  testWidgets('a fresh document step offers to start', (tester) async {
    await _pump(tester, governmentId: {'status': 'not_started'});

    expect(find.text('Start verification'), findsOneWidget);
  });

  testWidgets('a pending attempt offers to continue instead', (tester) async {
    await _pump(
      tester,
      governmentId: {
        'status': 'pending',
        'documentType': 'nin_slip',
        'documentNumberLast4': '0008',
      },
    );

    expect(find.text('Continue verification'), findsOneWidget);
    expect(find.text('Start verification'), findsNothing);
  });

  testWidgets('the card names the document the server recorded', (
    tester,
  ) async {
    await _pump(
      tester,
      governmentId: {'status': 'pending', 'documentType': 'nin_slip'},
    );

    expect(find.text(GovernmentIdDocumentType.ninSlip.label), findsOneWidget);
  });
}
