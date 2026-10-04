import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/preferences.dart';
import '../../../app/route_arguments.dart';
import '../../../app/services.dart';
import '../../../helper/device_identity_service.dart';
import '../../../helper/fcm_service.dart';
import '../../../utils/auth_input.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../service/auth_service.dart';
import 'test_otp_provider.dart';

final signupFlowProvider =
    NotifierProvider<SignupFlowNotifier, NotifierState<SignupFlowData>>(
      SignupFlowNotifier.new,
    );

class SignupFlowNotifier extends Notifier<NotifierState<SignupFlowData>> {
  @override
  NotifierState<SignupFlowData> build() =>
      const NotifierState.idle(data: SignupFlowData());

  Future<void> startEmail(String rawEmail) async {
    final identifier = normalizeEmailAddress(rawEmail);
    await _start(
      EmailSignupRequest(identifier),
      identifier,
      IdentifierType.email,
      null,
    );
  }

  Future<void> startPhone(
    String rawPhone,
    PhoneVerificationChannel channel,
  ) async {
    final identifier = normalizeNigerianPhone(rawPhone);
    await _start(
      PhoneSignupRequest(identifier, channel),
      identifier,
      IdentifierType.phoneNumber,
      channel,
    );
  }

  Future<void> _start(
    SignupRequest request,
    String identifier,
    IdentifierType type,
    PhoneVerificationChannel? channel,
  ) async {
    final context = SignupFlowData(
      identifier: identifier,
      identifierType: type,
      phoneVerificationChannel: channel,
    );
    if (!isValidIdentifier(identifier, type)) {
      state = NotifierState.error(
        type == IdentifierType.email
            ? 'Enter a valid email address.'
            : 'Enter a valid Nigerian phone number.',
        data: context,
      );
      return;
    }
    state = NotifierState.loading(data: context);
    final response = await ref.read(authServiceProvider).signup(request);
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    final next = context.copyWith(
      stage: SignupFlowStage.awaitingOtp,
      userId: dto.userId,
      verificationId: dto.otp.verificationId,
      otpExpiresAt: dto.otp.expiresAt,
      isSignupResumed: dto.isSignupResumed,
    );
    ref.read(testOtpProvider.notifier).show(TestOtpFlow.signup, dto.otp);
    state = NotifierState.done(
      next,
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    await ref
        .read(sharedPreferencesProvider)
        .setBool(hasSeenOnboardingKey, true);
    ref
        .read(authNavigationProvider.notifier)
        .publish(
          AuthDestination.signupOtp,
          mode: AuthNavigationMode.push,
          message: response.message,
          messageTone: AppMessageTone.success,
        );
  }

  Future<void> resendOtp() async {
    final context = state.data;
    if (context == null || context.stage != SignupFlowStage.awaitingOtp) {
      _localError('Signup OTP cannot be requested from this step.');
      return;
    }
    state = NotifierState.loading(data: context);
    final request = context.identifierType == IdentifierType.phoneNumber
        ? RequestOtpRequest.phone(
            context.identifier,
            OtpPurpose.signup,
            context.phoneVerificationChannel!,
          )
        : RequestOtpRequest.email(context.identifier, OtpPurpose.signup);
    final response = await ref.read(authServiceProvider).requestOtp(request);
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    ref.read(testOtpProvider.notifier).show(TestOtpFlow.signup, dto.otp);
    state = NotifierState.done(
      context.copyWith(
        verificationId: dto.otp.verificationId,
        otpExpiresAt: dto.otp.expiresAt,
      ),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> verifyAccount(String otpCode) async {
    final context = state.data;
    if (context == null || context.stage != SignupFlowStage.awaitingOtp) {
      _localError('Account verification cannot run from this step.');
      return;
    }
    if (!isValidOtpCode(otpCode)) {
      _localError('Enter a valid 6-digit code.');
      return;
    }
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.signup);
    state = NotifierState.loading(data: context);
    late final String deviceToken;
    try {
      deviceToken = await ref.read(deviceIdentityServiceProvider).getOrCreate();
    } catch (_) {
      _localError('Unable to create a secure device identity. Please retry.');
      return;
    }
    String? fcmToken;
    try {
      fcmToken = await ref.read(fcmServiceProvider).getToken();
    } catch (_) {
      fcmToken = null;
    }
    final response = await ref
        .read(authServiceProvider)
        .verifyAccount(
          VerifyAccountRequest(
            identifier: context.identifier,
            otpCode: otpCode,
            deviceToken: deviceToken,
            fcmToken: fcmToken,
          ),
        );
    if (!response.isDone) {
      state = response.failureWith(context);
      return;
    }
    state = NotifierState.done(
      context.copyWith(stage: SignupFlowStage.creatingPassword),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    ref
        .read(authNavigationProvider.notifier)
        .publish(
          AuthDestination.createPassword,
          mode: AuthNavigationMode.push,
          message: response.message,
          messageTone: AppMessageTone.success,
        );
  }

  Future<void> createPassword(String password) async {
    final context = state.data;
    if (context == null || context.stage != SignupFlowStage.creatingPassword) {
      _localError('A password cannot be created from this step.');
      return;
    }
    if (!isValidApiPassword(password)) {
      _localError(
        'Use at least 8 characters with a letter, number, and special character.',
      );
      return;
    }
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .createFirstPassword(
          CreateFirstPasswordRequest(
            identifier: context.identifier,
            password: password,
          ),
        );
    if (!response.isDone) {
      state = response.failureWith(context);
      return;
    }
    state = NotifierState.done(
      context.copyWith(stage: SignupFlowStage.completed),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.signup);
    ref
        .read(authNavigationProvider.notifier)
        .publish(
          AuthDestination.login,
          mode: AuthNavigationMode.clearStack,
          message: response.message,
          messageTone: AppMessageTone.success,
        );
  }

  void _localError(String message) {
    state = NotifierState.error(message, data: state.data);
  }
}
