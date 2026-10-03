import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_phone_requirement.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KYC requires both a verified flag and a non-blank phone number', () {
    expect(isPhoneReadyForKyc(null), isFalse);
    expect(isPhoneReadyForKyc(_profile(phone: '+2348012345678')), isFalse);
    expect(isPhoneReadyForKyc(_profile(phoneVerified: true)), isFalse);
    expect(
      isPhoneReadyForKyc(_profile(phone: ' ', phoneVerified: true)),
      isFalse,
    );
    expect(
      isPhoneReadyForKyc(
        _profile(phone: '+2348012345678', phoneVerified: true),
      ),
      isTrue,
    );
  });

  test('KYC next action parses verify_phone_number', () {
    expect(
      KycNextAction.fromWire('verify_phone_number'),
      KycNextAction.verifyPhoneNumber,
    );
  });
}

UserOwnProfileData _profile({String? phone, bool phoneVerified = false}) =>
    UserOwnProfileData(
      userId: 'user-1',
      phoneNumber: phone,
      tier: 0,
      status: 'active',
      transactionStatus: 'active',
      isVerifiedAccount: false,
      isVerifiedEmail: true,
      isVerifiedPhoneNumber: phoneVerified,
      isCreatedPassword: true,
      isCreatedPin: true,
    );
