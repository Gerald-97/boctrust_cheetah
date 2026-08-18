import 'package:equatable/equatable.dart';

import 'auth_enums.dart';

Map<String, Object?> _map(Object? json) =>
    Map<String, Object?>.from(json! as Map);
String _string(Map<String, Object?> json, String key) => json[key]! as String;

class EmptyData extends Equatable {
  const EmptyData();
  factory EmptyData.fromJson(Object? _) => const EmptyData();

  @override
  List<Object?> get props => const [];
}

class NotificationDetails extends Equatable {
  const NotificationDetails({
    required this.requestedChannel,
    required this.actualChannel,
    required this.destination,
    required this.provider,
    required this.delivered,
    this.fallbackApplied,
    this.skipped,
    this.reason,
  });

  factory NotificationDetails.fromJson(Object? value) {
    final json = _map(value);
    return NotificationDetails(
      requestedChannel: NotificationChannel.fromWire(json['requestedChannel']),
      actualChannel: NotificationChannel.fromWire(json['actualChannel']),
      destination: _string(json, 'destination'),
      provider: NotificationProvider.fromWire(json['provider']),
      delivered: json['delivered']! as bool,
      fallbackApplied: json['fallbackApplied'] as bool?,
      skipped: json['skipped'] as bool?,
      reason: json['reason'] as String?,
    );
  }

  final NotificationChannel requestedChannel;
  final NotificationChannel actualChannel;
  final String destination;
  final NotificationProvider provider;
  final bool delivered;
  final bool? fallbackApplied;
  final bool? skipped;
  final String? reason;

  @override
  List<Object?> get props => [
    requestedChannel,
    actualChannel,
    destination,
    provider,
    delivered,
    fallbackApplied,
    skipped,
    reason,
  ];
}

class OtpData extends Equatable {
  const OtpData({
    required this.verificationId,
    required this.expiresAt,
    this.otpCode,
    required this.notification,
  });

  factory OtpData.fromJson(Object? value) {
    final json = _map(value);
    return OtpData(
      verificationId: _string(json, 'verificationId'),
      expiresAt: DateTime.parse(_string(json, 'expiresAt')).toUtc(),
      otpCode: json['otpCode'] as String?,
      notification: NotificationDetails.fromJson(json['notification']),
    );
  }

  final String verificationId;
  final DateTime expiresAt;
  final String? otpCode;
  final NotificationDetails notification;

  @override
  List<Object?> get props => [verificationId, expiresAt, otpCode, notification];
}

class SignupData extends Equatable {
  const SignupData({
    required this.userId,
    required this.otp,
    this.isSignupResumed = false,
  });
  factory SignupData.fromJson(Object? value) {
    final json = _map(value);
    return SignupData(
      userId: _string(json, 'userId'),
      otp: OtpData.fromJson(json['otp']),
      isSignupResumed: json['isSignupResumed'] as bool? ?? false,
    );
  }
  final String userId;
  final OtpData otp;
  final bool isSignupResumed;

  @override
  List<Object?> get props => [userId, otp, isSignupResumed];
}

class RequestOtpData extends Equatable {
  const RequestOtpData({
    required this.purpose,
    required this.userId,
    required this.otp,
    this.isSignupResumed,
  });
  factory RequestOtpData.fromJson(Object? value) {
    final json = _map(value);
    return RequestOtpData(
      purpose: OtpPurpose.fromWire(json['purpose']),
      userId: _string(json, 'userId'),
      otp: OtpData.fromJson(json['otp']),
      isSignupResumed: json['isSignupResumed'] as bool?,
    );
  }
  final OtpPurpose purpose;
  final String userId;
  final OtpData otp;
  final bool? isSignupResumed;

  @override
  List<Object?> get props => [purpose, userId, otp, isSignupResumed];
}

class ResetTokenData extends Equatable {
  const ResetTokenData({
    required this.resetToken,
    required this.expiresInSeconds,
  });
  factory ResetTokenData.fromJson(Object? value) {
    final json = _map(value);
    return ResetTokenData(
      resetToken: _string(json, 'resetToken'),
      expiresInSeconds: json['expiresInSeconds']! as num,
    );
  }
  final String resetToken;
  final num expiresInSeconds;

  @override
  List<Object?> get props => [resetToken, expiresInSeconds];
}

class CreateFirstPasswordData extends Equatable {
  const CreateFirstPasswordData({
    required this.userId,
    required this.welcomeNotification,
  });
  factory CreateFirstPasswordData.fromJson(Object? value) {
    final json = _map(value);
    return CreateFirstPasswordData(
      userId: _string(json, 'userId'),
      welcomeNotification: NotificationDetails.fromJson(
        json['welcomeNotification'],
      ),
    );
  }
  final String userId;
  final NotificationDetails welcomeNotification;

  @override
  List<Object?> get props => [userId, welcomeNotification];
}

class CreateFirstPinData extends Equatable {
  const CreateFirstPinData({required this.userId, required this.isCreatedPin});
  factory CreateFirstPinData.fromJson(Object? value) {
    final json = _map(value);
    return CreateFirstPinData(
      userId: _string(json, 'userId'),
      isCreatedPin: json['isCreatedPin']! as bool,
    );
  }
  final String userId;
  final bool isCreatedPin;

  @override
  List<Object?> get props => [userId, isCreatedPin];
}

class LoginUserData extends Equatable {
  const LoginUserData({
    required this.userId,
    this.email,
    this.phoneNumber,
    required this.identifierType,
  });
  factory LoginUserData.fromJson(Object? value) {
    final json = _map(value);
    return LoginUserData(
      userId: _string(json, 'userId'),
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      identifierType: IdentifierType.fromWire(json['identifierType']),
    );
  }
  final String userId;
  final String? email;
  final String? phoneNumber;
  final IdentifierType identifierType;

  @override
  List<Object?> get props => [userId, email, phoneNumber, identifierType];
}

class LoginData extends Equatable {
  const LoginData({
    required this.accessToken,
    required this.expiresInSeconds,
    required this.user,
  });
  factory LoginData.fromJson(Object? value) {
    final json = _map(value);
    return LoginData(
      accessToken: _string(json, 'accessToken'),
      expiresInSeconds: json['expiresInSeconds']! as num,
      user: LoginUserData.fromJson(json['user']),
    );
  }
  final String accessToken;
  final num expiresInSeconds;
  final LoginUserData user;

  @override
  List<Object?> get props => [accessToken, expiresInSeconds, user];
}

class IdentifierVerificationInitiateData extends Equatable {
  const IdentifierVerificationInitiateData({
    required this.userId,
    required this.identifierType,
    required this.identifier,
    required this.otp,
  });
  factory IdentifierVerificationInitiateData.fromJson(Object? value) {
    final json = _map(value);
    return IdentifierVerificationInitiateData(
      userId: _string(json, 'userId'),
      identifierType: IdentifierType.fromWire(json['identifierType']),
      identifier: _string(json, 'identifier'),
      otp: OtpData.fromJson(json['otp']),
    );
  }
  final String userId;
  final IdentifierType identifierType;
  final String identifier;
  final OtpData otp;

  @override
  List<Object?> get props => [userId, identifierType, identifier, otp];
}

class IdentifierVerificationVerifyData extends Equatable {
  const IdentifierVerificationVerifyData({
    required this.userId,
    required this.identifierType,
    required this.identifier,
  });
  factory IdentifierVerificationVerifyData.fromJson(Object? value) {
    final json = _map(value);
    return IdentifierVerificationVerifyData(
      userId: _string(json, 'userId'),
      identifierType: IdentifierType.fromWire(json['identifierType']),
      identifier: _string(json, 'identifier'),
    );
  }
  final String userId;
  final IdentifierType identifierType;
  final String identifier;

  @override
  List<Object?> get props => [userId, identifierType, identifier];
}
