import '../../account/model/user_profile_model.dart';

/// KYC may only start once the customer has a verified phone number.
bool isPhoneReadyForKyc(UserOwnProfileData? profile) =>
    profile != null &&
    profile.isVerifiedPhoneNumber &&
    (profile.phoneNumber?.trim().isNotEmpty ?? false);
