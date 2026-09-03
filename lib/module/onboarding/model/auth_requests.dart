import 'auth_enums.dart';

abstract interface class JsonRequest {
  Map<String, Object?> toJson();
}

sealed class SignupRequest implements JsonRequest {
  const SignupRequest();
}

class EmailSignupRequest extends SignupRequest {
  const EmailSignupRequest(this.email);
  final String email;

  @override
  Map<String, Object?> toJson() => {'email': email};
}

class PhoneSignupRequest extends SignupRequest {
  const PhoneSignupRequest(this.phoneNumber, this.channel);
  final String phoneNumber;
  final PhoneVerificationChannel channel;

  @override
  Map<String, Object?> toJson() => {
    'phoneNumber': phoneNumber,
    'phoneVerificationChannel': channel.wireValue,
  };
}

class RequestOtpRequest implements JsonRequest {
  const RequestOtpRequest._({
    required this.identifier,
    required this.purpose,
    this.phoneVerificationChannel,
  });

  factory RequestOtpRequest.email(String identifier, OtpPurpose purpose) =>
      RequestOtpRequest._(identifier: identifier, purpose: purpose);

  factory RequestOtpRequest.phone(
    String identifier,
    OtpPurpose purpose,
    PhoneVerificationChannel channel,
  ) => RequestOtpRequest._(
    identifier: identifier,
    purpose: purpose,
    phoneVerificationChannel: channel,
  );

  final String identifier;
  final OtpPurpose purpose;
  final PhoneVerificationChannel? phoneVerificationChannel;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'purpose': purpose.wireValue,
    if (phoneVerificationChannel != null)
      'phoneVerificationChannel': phoneVerificationChannel!.wireValue,
  };
}

class VerifyAccountRequest implements JsonRequest {
  const VerifyAccountRequest({
    required this.identifier,
    required this.otpCode,
    required this.deviceToken,
    this.fcmToken,
  });
  final String identifier;
  final String otpCode;
  final String deviceToken;
  final String? fcmToken;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'otpCode': otpCode,
    'deviceToken': deviceToken,
    if (fcmToken != null) 'fcmToken': fcmToken,
  };
}

class CreateFirstPasswordRequest implements JsonRequest {
  const CreateFirstPasswordRequest({
    required this.identifier,
    required this.password,
  });
  final String identifier;
  final String password;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'password': password,
  };
}

class ForgotRequest implements JsonRequest {
  const ForgotRequest._({required this.identifier, this.channel});

  factory ForgotRequest.email(String identifier) =>
      ForgotRequest._(identifier: identifier);
  factory ForgotRequest.phone(
    String identifier,
    PhoneVerificationChannel channel,
  ) => ForgotRequest._(identifier: identifier, channel: channel);

  final String identifier;
  final PhoneVerificationChannel? channel;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    if (channel != null) 'phoneVerificationChannel': channel!.wireValue,
  };
}

class VerifyOtpRequest implements JsonRequest {
  const VerifyOtpRequest({required this.identifier, required this.otpCode});
  final String identifier;
  final String otpCode;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'otpCode': otpCode,
  };
}

class ResetPasswordRequest implements JsonRequest {
  const ResetPasswordRequest({
    required this.resetToken,
    required this.newPassword,
  });
  final String resetToken;
  final String newPassword;

  @override
  Map<String, Object?> toJson() => {
    'resetToken': resetToken,
    'newPassword': newPassword,
  };
}

class ChangePasswordRequest implements JsonRequest {
  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });
  final String currentPassword;
  final String newPassword;

  @override
  Map<String, Object?> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };
}

class ResetPinRequest implements JsonRequest {
  const ResetPinRequest({required this.resetToken, required this.newPin});
  final String resetToken;
  final String newPin;

  @override
  Map<String, Object?> toJson() => {'resetToken': resetToken, 'newPin': newPin};
}

class CreateFirstPinRequest implements JsonRequest {
  const CreateFirstPinRequest(this.pin);
  final String pin;

  @override
  Map<String, Object?> toJson() => {'pin': pin};
}

class ChangePinRequest implements JsonRequest {
  const ChangePinRequest({required this.currentPin, required this.newPin});
  final String currentPin;
  final String newPin;

  @override
  Map<String, Object?> toJson() => {'currentPin': currentPin, 'newPin': newPin};
}

class LoginRequest implements JsonRequest {
  const LoginRequest({
    required this.identifier,
    required this.password,
    required this.deviceToken,
  });
  final String identifier;
  final String password;
  final String deviceToken;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'password': password,
    'deviceToken': deviceToken,
  };
}

class VerifyCurrentPasswordRequest implements JsonRequest {
  const VerifyCurrentPasswordRequest(this.currentPassword);
  final String currentPassword;

  @override
  Map<String, Object?> toJson() => {'currentPassword': currentPassword};
}

class VerifyCurrentPinRequest implements JsonRequest {
  const VerifyCurrentPinRequest(this.currentPin);
  final String currentPin;

  @override
  Map<String, Object?> toJson() => {'currentPin': currentPin};
}

class VerifyNewDeviceRequest implements JsonRequest {
  const VerifyNewDeviceRequest({
    required this.identifier,
    required this.otpCode,
    required this.deviceToken,
    this.fcmToken,
  });
  final String identifier;
  final String otpCode;
  final String deviceToken;
  final String? fcmToken;

  @override
  Map<String, Object?> toJson() => {
    'identifier': identifier,
    'otpCode': otpCode,
    'deviceToken': deviceToken,
    if (fcmToken != null) 'fcmToken': fcmToken,
  };
}

class UpdateFcmTokenRequest implements JsonRequest {
  const UpdateFcmTokenRequest(this.fcmToken);
  final String fcmToken;

  @override
  Map<String, Object?> toJson() => {'fcmToken': fcmToken};
}

sealed class InitiateIdentifierVerificationRequest implements JsonRequest {
  const InitiateIdentifierVerificationRequest();
}

class EmailIdentifierVerificationRequest
    extends InitiateIdentifierVerificationRequest {
  const EmailIdentifierVerificationRequest(this.email);
  final String email;

  @override
  Map<String, Object?> toJson() => {
    'identifierType': IdentifierType.email.wireValue,
    'email': email,
  };
}

class PhoneIdentifierVerificationRequest
    extends InitiateIdentifierVerificationRequest {
  const PhoneIdentifierVerificationRequest({
    required this.phoneNumber,
    required this.channel,
  });
  final String phoneNumber;
  final PhoneVerificationChannel channel;

  @override
  Map<String, Object?> toJson() => {
    'identifierType': IdentifierType.phoneNumber.wireValue,
    'phoneNumber': phoneNumber,
    'phoneVerificationChannel': channel.wireValue,
  };
}
