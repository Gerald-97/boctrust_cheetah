import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _Kyc extends KycService {
  _Kyc(this.governmentId) : super(ApiService(Dio()));

  final Map<String, Object?> governmentId;

  @override
  Future<NotifierState<KycStatusData>> getStatus() async =>
      NotifierState.done(_status(governmentId));
}

class _Users extends UserService {
  _Users() : super(ApiService(Dio()));

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      const NotifierState<UserTierInfoData>.error('stub');
}

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, Object?> governmentId,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await pumpFlow(
    tester,
    route: '/account/tier/government-id',
    overrides: [
      kycServiceProvider.overrideWithValue(_Kyc(governmentId)),
      userServiceProvider.overrideWithValue(_Users()),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every document type can be chosen by its own name', (
    tester,
  ) async {
    await _pump(tester, governmentId: {'status': 'not_started'});

    for (final type in GovernmentIdDocumentType.values) {
      await tester.tap(
        find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(type.label).last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<GovernmentIdDocumentType>>(
              find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
            )
            .initialValue,
        type,
        reason: 'selecting ${type.wireValue} left the dropdown unchanged',
      );
    }
  });

  testWidgets('each document type reads as words, never as a wire key', (
    tester,
  ) async {
    await _pump(tester, governmentId: {'status': 'not_started'});
    await tester.tap(
      find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
    );
    await tester.pumpAndSettle();

    for (final type in GovernmentIdDocumentType.values) {
      expect(find.text(type.label), findsWidgets);
      expect(find.textContaining(type.wireValue), findsNothing);
    }
  });

  testWidgets('a missing document number blocks the attempt', (tester) async {
    // The backend rejects an initiation without one, so the form must catch
    // it rather than spend a round trip discovering it.
    await _pump(tester, governmentId: {'status': 'not_started'});

    await tester.tap(find.text('Start verification'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter the document number'), findsOneWidget);
  });

  testWidgets('the number field names the chosen document', (tester) async {
    await _pump(tester, governmentId: {'status': 'not_started'});
    await tester.tap(
      find.byType(DropdownButtonFormField<GovernmentIdDocumentType>),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(GovernmentIdDocumentType.internationalPassport.label).last,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'As printed on your '
        '${GovernmentIdDocumentType.internationalPassport.label}',
      ),
      findsOneWidget,
    );
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
