import '../../account/model/user_profile_model.dart';

/// Whether the profile has a verified, non-blank email address.
bool isEmailReadyForKyc(UserOwnProfileData? profile) =>
    profile != null &&
    profile.isVerifiedEmail &&
    (profile.email?.trim().isNotEmpty ?? false);

/// Whether the profile has a verified, non-blank phone number.
bool isPhoneReadyForKyc(UserOwnProfileData? profile) =>
    profile != null &&
    profile.isVerifiedPhoneNumber &&
    (profile.phoneNumber?.trim().isNotEmpty ?? false);

/// KYC may only start once both the email and the phone are verified.
bool areContactsReadyForKyc(UserOwnProfileData? profile) =>
    isEmailReadyForKyc(profile) && isPhoneReadyForKyc(profile);

/// The contact details still to verify, for copy; null when none remain.
String? missingKycContacts(UserOwnProfileData? profile) =>
    switch ((isEmailReadyForKyc(profile), isPhoneReadyForKyc(profile))) {
      (true, true) => null,
      (false, false) => 'email address and phone number',
      (false, true) => 'email address',
      (true, false) => 'phone number',
    };
