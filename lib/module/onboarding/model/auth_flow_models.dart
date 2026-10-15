import 'package:equatable/equatable.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../account/model/user_profile_model.dart';
import 'auth_enums.dart';

enum StartupGateStage {
  idle,
  clearingSession,
  loadingProfile,
  profileError,
  complete,
}

class StartupGateData extends Equatable {
  const StartupGateData({this.stage = StartupGateStage.idle, this.destination});
  final StartupGateStage stage;
  final AuthDestination? destination;

  StartupGateData copyWith({
    StartupGateStage? stage,
    AuthDestination? destination,
  }) => StartupGateData(
    stage: stage ?? this.stage,
    destination: destination ?? this.destination,
  );

  @override
  List<Object?> get props => [stage, destination];
}

enum SignupFlowStage { idle, awaitingOtp, creatingPassword, completed }

class SignupFlowData extends Equatable {
  const SignupFlowData({
    this.stage = SignupFlowStage.idle,
    this.identifier = '',
    this.identifierType = IdentifierType.unknown,
    this.phoneVerificationChannel,
    this.userId,
    this.verificationId,
    this.otpExpiresAt,
    this.isSignupResumed = false,
  });
  final SignupFlowStage stage;
  final String identifier;
  final IdentifierType identifierType;
  final PhoneVerificationChannel? phoneVerificationChannel;
  final String? userId;
  final String? verificationId;
  final DateTime? otpExpiresAt;
  final bool isSignupResumed;

  SignupFlowData copyWith({
    SignupFlowStage? stage,
    String? identifier,
    IdentifierType? identifierType,
    PhoneVerificationChannel? phoneVerificationChannel,
    String? userId,
    String? verificationId,
    DateTime? otpExpiresAt,
    bool? isSignupResumed,
  }) => SignupFlowData(
    stage: stage ?? this.stage,
    identifier: identifier ?? this.identifier,
    identifierType: identifierType ?? this.identifierType,
    phoneVerificationChannel:
        phoneVerificationChannel ?? this.phoneVerificationChannel,
    userId: userId ?? this.userId,
    verificationId: verificationId ?? this.verificationId,
    otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
    isSignupResumed: isSignupResumed ?? this.isSignupResumed,
  );

  @override
  List<Object?> get props => [
    stage,
    identifier,
    identifierType,
    phoneVerificationChannel,
    userId,
    verificationId,
    otpExpiresAt,
    isSignupResumed,
  ];
}

enum LoginAttemptOutcome {
  completed,
  invalidInput,
  invalidCredentials,
  deviceIdentityFailure,
  requestFailure,
  cancelled,
}

/// How one call to `LoginFlowNotifier.login` ended. Never carries a secret.
class LoginAttemptResult extends Equatable {
  const LoginAttemptResult({
    required this.outcome,
    required this.identifier,
    this.message,
  });

  final LoginAttemptOutcome outcome;
  final String identifier;
  final String? message;

  bool get isCompleted => outcome == LoginAttemptOutcome.completed;

  @override
  List<Object?> get props => [outcome, identifier, message];
}

enum LoginFlowStage {
  idle,
  submitting,
  choosingNewDeviceChannel,
  requestingNewDeviceOtp,
  awaitingNewDeviceOtp,
  verifyingNewDevice,
  retryingAfterDeviceApproval,
  completed,
}

class LoginFlowData extends Equatable {
  const LoginFlowData({
    this.stage = LoginFlowStage.idle,
    this.identifier = '',
    this.identifierType = IdentifierType.unknown,
    this.phoneVerificationChannel,
    this.verificationId,
    this.otpExpiresAt,
  });
  final LoginFlowStage stage;
  final String identifier;
  final IdentifierType identifierType;
  final PhoneVerificationChannel? phoneVerificationChannel;
  final String? verificationId;
  final DateTime? otpExpiresAt;

  LoginFlowData copyWith({
    LoginFlowStage? stage,
    String? identifier,
    IdentifierType? identifierType,
    PhoneVerificationChannel? phoneVerificationChannel,
    String? verificationId,
    DateTime? otpExpiresAt,
  }) => LoginFlowData(
    stage: stage ?? this.stage,
    identifier: identifier ?? this.identifier,
    identifierType: identifierType ?? this.identifierType,
    phoneVerificationChannel:
        phoneVerificationChannel ?? this.phoneVerificationChannel,
    verificationId: verificationId ?? this.verificationId,
    otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
  );

  @override
  List<Object?> get props => [
    stage,
    identifier,
    identifierType,
    phoneVerificationChannel,
    verificationId,
    otpExpiresAt,
  ];
}

enum RecoveryFlowStage { idle, awaitingOtp, awaitingNewSecret, completed }

class PasswordRecoveryFlowData extends Equatable {
  const PasswordRecoveryFlowData({
    this.stage = RecoveryFlowStage.idle,
    this.identifier = '',
    this.identifierType = IdentifierType.unknown,
    this.phoneVerificationChannel,
    this.verificationId,
    this.otpExpiresAt,
  });
  final RecoveryFlowStage stage;
  final String identifier;
  final IdentifierType identifierType;
  final PhoneVerificationChannel? phoneVerificationChannel;
  final String? verificationId;
  final DateTime? otpExpiresAt;

  PasswordRecoveryFlowData copyWith({
    RecoveryFlowStage? stage,
    String? identifier,
    IdentifierType? identifierType,
    PhoneVerificationChannel? phoneVerificationChannel,
    String? verificationId,
    DateTime? otpExpiresAt,
  }) => PasswordRecoveryFlowData(
    stage: stage ?? this.stage,
    identifier: identifier ?? this.identifier,
    identifierType: identifierType ?? this.identifierType,
    phoneVerificationChannel:
        phoneVerificationChannel ?? this.phoneVerificationChannel,
    verificationId: verificationId ?? this.verificationId,
    otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
  );

  @override
  List<Object?> get props => [
    stage,
    identifier,
    identifierType,
    phoneVerificationChannel,
    verificationId,
    otpExpiresAt,
  ];
}

class PinRecoveryFlowData extends Equatable {
  const PinRecoveryFlowData({
    this.stage = RecoveryFlowStage.idle,
    this.identifier = '',
    this.identifierType = IdentifierType.unknown,
    this.phoneVerificationChannel,
    this.verificationId,
    this.otpExpiresAt,
  });
  final RecoveryFlowStage stage;
  final String identifier;
  final IdentifierType identifierType;
  final PhoneVerificationChannel? phoneVerificationChannel;
  final String? verificationId;
  final DateTime? otpExpiresAt;

  PinRecoveryFlowData copyWith({
    RecoveryFlowStage? stage,
    String? identifier,
    IdentifierType? identifierType,
    PhoneVerificationChannel? phoneVerificationChannel,
    String? verificationId,
    DateTime? otpExpiresAt,
  }) => PinRecoveryFlowData(
    stage: stage ?? this.stage,
    identifier: identifier ?? this.identifier,
    identifierType: identifierType ?? this.identifierType,
    phoneVerificationChannel:
        phoneVerificationChannel ?? this.phoneVerificationChannel,
    verificationId: verificationId ?? this.verificationId,
    otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
  );

  @override
  List<Object?> get props => [
    stage,
    identifier,
    identifierType,
    phoneVerificationChannel,
    verificationId,
    otpExpiresAt,
  ];
}

enum IdentifierVerificationStage { idle, awaitingOtp, completed }

class IdentifierVerificationFlowData extends Equatable {
  const IdentifierVerificationFlowData({
    this.stage = IdentifierVerificationStage.idle,
    this.identifier = '',
    this.identifierType = IdentifierType.unknown,
    this.phoneVerificationChannel,
    this.verificationId,
    this.otpExpiresAt,
  });
  final IdentifierVerificationStage stage;
  final String identifier;
  final IdentifierType identifierType;
  final PhoneVerificationChannel? phoneVerificationChannel;
  final String? verificationId;
  final DateTime? otpExpiresAt;

  IdentifierVerificationFlowData copyWith({
    IdentifierVerificationStage? stage,
    String? identifier,
    IdentifierType? identifierType,
    PhoneVerificationChannel? phoneVerificationChannel,
    String? verificationId,
    DateTime? otpExpiresAt,
  }) => IdentifierVerificationFlowData(
    stage: stage ?? this.stage,
    identifier: identifier ?? this.identifier,
    identifierType: identifierType ?? this.identifierType,
    phoneVerificationChannel:
        phoneVerificationChannel ?? this.phoneVerificationChannel,
    verificationId: verificationId ?? this.verificationId,
    otpExpiresAt: otpExpiresAt ?? this.otpExpiresAt,
  );

  @override
  List<Object?> get props => [
    stage,
    identifier,
    identifierType,
    phoneVerificationChannel,
    verificationId,
    otpExpiresAt,
  ];
}

enum PostLoginBootstrapStage { idle, loadingProfile, profileError, ready }

class PostLoginBootstrapData extends Equatable {
  const PostLoginBootstrapData({
    this.stage = PostLoginBootstrapStage.idle,
    this.profile,
  });
  final PostLoginBootstrapStage stage;
  final UserOwnProfileData? profile;

  PostLoginBootstrapData copyWith({
    PostLoginBootstrapStage? stage,
    UserOwnProfileData? profile,
  }) => PostLoginBootstrapData(
    stage: stage ?? this.stage,
    profile: profile ?? this.profile,
  );

  @override
  List<Object?> get props => [stage, profile];
}

enum FcmRegistrationStage {
  idle,
  permissionDenied,
  registering,
  registered,
  retryableFailure,
}

class FcmRegistrationData extends Equatable {
  const FcmRegistrationData({
    this.stage = FcmRegistrationStage.idle,
    this.lastAttemptAt,
  });
  final FcmRegistrationStage stage;
  final DateTime? lastAttemptAt;

  FcmRegistrationData copyWith({
    FcmRegistrationStage? stage,
    DateTime? lastAttemptAt,
  }) => FcmRegistrationData(
    stage: stage ?? this.stage,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
  );

  @override
  List<Object?> get props => [stage, lastAttemptAt];
}
