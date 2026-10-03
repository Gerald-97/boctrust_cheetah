import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_requests.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_responses.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/identifier_verification_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Auth extends AuthService {
  _Auth() : super(ApiService(Dio()));

  @override
  Future<NotifierState<IdentifierVerificationInitiateData>>
  initiateIdentifierVerification(
    InitiateIdentifierVerificationRequest request,
  ) async => NotifierState.done(
    IdentifierVerificationInitiateData.fromJson({
      'userId': 'user-1',
      'identifierType': 'phone_number',
      'identifier': '+2348012345678',
      'otp': {
        'verificationId': 'otp-1',
        'expiresAt': '2026-10-03T12:00:00Z',
        'notification': {
          'requestedChannel': 'sms',
          'actualChannel': 'sms',
          'destination': '+2348012345678',
          'provider': 'termii',
          'delivered': true,
        },
      },
    }),
  );

  @override
  Future<NotifierState<IdentifierVerificationVerifyData>> verifyIdentifier(
    VerifyOtpRequest request,
  ) async => NotifierState.done(
    IdentifierVerificationVerifyData.fromJson({
      'userId': 'user-1',
      'identifierType': 'phone_number',
      'identifier': '+2348012345678',
    }),
  );
}

class _Users extends UserService {
  _Users() : super(ApiService(Dio()));
  var profileLoads = 0;

  @override
  Future<NotifierState<UserOwnProfileData>> getOwnProfile() async {
    profileLoads++;
    return const NotifierState.error('stub');
  }

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      const NotifierState.error('stub');
}

void main() {
  test('a verified phone number reloads the profile', () async {
    final users = _Users();
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_Auth()),
        userServiceProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(identifierVerificationProvider.notifier);

    await notifier.initiatePhone('08012345678', PhoneVerificationChannel.sms);
    await notifier.verify('123456');
    await pumpEventQueue();

    expect(users.profileLoads, 1);
  });
}
