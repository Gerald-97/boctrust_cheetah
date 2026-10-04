import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/kyc_configuration_fixtures.dart';
import 'support/flow_harness.dart';

/// A legacy Smile document initiation: no contract version, and the Smile job
/// context `validateKycLaunch` recognises.
KycInitiationData _smileGovernmentId() => KycInitiationData.fromJson({
  'verificationId': 'verification-1',
  'product': 'enhanced_document_verification',
  'sdkJobType': 'enhancedDocumentVerification',
  'environment': 'live',
  'country': 'NG',
  'documentType': 'nin_slip',
  'smileUserId': 'smile-user-1',
  'smileJobId': 'smile-job-1',
  'callbackUrl': 'https://user.example.test/document-webhook',
  'partnerParams': {
    'user_id': 'smile-user-1',
    'job_id': 'smile-job-1',
    'job_type': 11,
  },
});

KycStatusData _notStarted() => KycStatusData.fromJson({
  'userId': 'user-1',
  'tier': 0,
  'identity': {'status': 'not_started'},
  'governmentId': {'status': 'not_started'},
  'utilityBill': {'status': 'not_started'},
  'nextAction': 'verify_government_id',
});

class _Kyc extends KycService with KycConfigurationFixture {
  _Kyc() : super(ApiService(Dio()));

  @override
  Future<NotifierState<KycStatusData>> getStatus() async =>
      NotifierState.done(_notStarted());

  @override
  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) async => NotifierState.done(_smileGovernmentId());
}

class _Users extends UserService {
  _Users() : super(ApiService(Dio()));

  // KYC only opens once a verified email and phone are on file.
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
  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      const NotifierState<UserTierInfoData>.error('stub');
}

void main() {
  testWidgets('a Smile fallback names a document the user can switch to', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Messages leave as toasts over a platform channel, so the channel
    // payload is the only place to read what the user was told.
    final toasts = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        final arguments = call.arguments;
        if (arguments is Map) toasts.add('${arguments['msg']}');
        return true;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      ),
    );

    await pumpFlow(
      tester,
      route: '/account/tier/government-id',
      overrides: [
        kycServiceProvider.overrideWithValue(_Kyc()),
        userServiceProvider.overrideWithValue(_Users()),
      ],
    );
    await tester.pumpAndSettle();

    // The configuration says Dojah, but the backend answers with Smile and
    // nin_slip, which Smile cannot verify. The initiation's provider decides.
    await tester.tap(find.text('Start verification'));
    // Bounded pumps: a pushed Smile capture screen animates forever, so
    // pumpAndSettle would time out instead of reporting the real failure.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(toasts, isNotEmpty);
    expect(toasts.last, contains(GovernmentIdDocumentType.ninSlip.label));
    expect(toasts.last, contains(GovernmentIdDocumentType.voterId.label));
  });
}
