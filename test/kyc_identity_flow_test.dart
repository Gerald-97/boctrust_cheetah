import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/service/home_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_providers.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

Map<String, Object?> _job({String id = 'job-1'}) => {
  'verificationId': 'verification-1',
  'product': 'biometric_kyc',
  'sdkJobType': 'biometricKyc',
  'environment': 'sandbox',
  'country': 'NG',
  'identityType': 'bvn',
  'identityLast4': '8901',
  'smileUserId': 'user-1',
  'smileJobId': id,
  'callbackUrl': 'https://example.test/callback',
  'partnerParams': {'job_type': 1},
};

class _Kyc extends KycService {
  _Kyc(this.responses) : super(ApiService(Dio()));
  final List<NotifierState<KycInitiationData>> responses;
  var calls = 0;
  @override
  Future<NotifierState<KycInitiationData>> initiateIdentity(
    IdentityVerificationRequest request,
  ) async => responses[calls++];
  @override
  Future<NotifierState<KycStatusData>> getStatus() async =>
      const NotifierState.error('stub');
}

class _Users extends UserService {
  _Users() : super(ApiService(Dio()));
  @override
  Future<NotifierState<UserOwnProfileData>> getOwnProfile() async =>
      const NotifierState.error('stub');
  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      const NotifierState.error('stub');
}

class _Home extends HomeService {
  _Home() : super(ApiService(Dio()));
  @override
  Future<NotifierState<UserHomeData>> getOwnHome() async =>
      const NotifierState.error('stub');
}

void main() {
  test(
    'BVN retries ask the server for a job instead of reusing cache',
    () async {
      final service = _Kyc([
        NotifierState.done(KycInitiationData.fromJson(_job())),
        NotifierState.done(KycInitiationData.fromJson(_job(id: 'job-2'))),
      ]);
      final container = ProviderContainer(
        overrides: [
          kycServiceProvider.overrideWithValue(service),
          userServiceProvider.overrideWithValue(_Users()),
          homeServiceProvider.overrideWithValue(_Home()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(identityVerificationProvider.notifier);

      final first = await notifier.submit(
        identityType: IdentityType.bvn,
        identityNumber: '12345678901',
      );
      notifier.markAwaitingProvider();
      final second = await notifier.submit(
        identityType: IdentityType.bvn,
        identityNumber: '12345678901',
      );

      expect(first?.smileJobId, 'job-1');
      expect(second?.smileJobId, 'job-2');
      expect(service.calls, 2);
    },
  );

  test('cancelling client state permits a later BVN attempt', () async {
    final service = _Kyc([
      NotifierState.done(KycInitiationData.fromJson(_job(id: 'job-1'))),
    ]);
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(service),
        userServiceProvider.overrideWithValue(_Users()),
        homeServiceProvider.overrideWithValue(_Home()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(identityVerificationProvider.notifier);
    notifier.cancelPendingRequest();
    final result = await notifier.submit(
      identityType: IdentityType.bvn,
      identityNumber: '12345678901',
    );
    expect(result?.smileJobId, 'job-1');
  });
}
