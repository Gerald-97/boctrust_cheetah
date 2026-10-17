import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/route_arguments.dart';
import '../../../app/services.dart';
import '../../../utils/auth_input.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../../core_banking/provider/biometric_transfer_provider.dart';
import '../service/auth_service.dart';
import 'biometric_login_provider.dart';
import 'test_otp_provider.dart';

final passwordRecoveryProvider =
    NotifierProvider<
      PasswordRecoveryNotifier,
      NotifierState<PasswordRecoveryFlowData>
    >(PasswordRecoveryNotifier.new);

class PasswordRecoveryNotifier
    extends Notifier<NotifierState<PasswordRecoveryFlowData>> {
  String? _resetToken;
  int _operationId = 0;

  @override
  NotifierState<PasswordRecoveryFlowData> build() {
    ref.onDispose(() {
      _operationId += 1;
      _resetToken = null;
    });
    return const NotifierState.idle(data: PasswordRecoveryFlowData());
  }

  Future<void> start(
    String rawIdentifier, {
    PhoneVerificationChannel? channel,
  }) async {
    final operationId = ++_operationId;
    final identifier = normalizeIdentifier(rawIdentifier);
    final type = identifierTypeFor(identifier);
    if (!isValidIdentifier(identifier, type)) {
      _error('Enter a valid email or Nigerian phone number.');
      return;
    }
    if (type == IdentifierType.phoneNumber && channel == null) {
      _error('Choose SMS or WhatsApp.');
      return;
    }
    final context = PasswordRecoveryFlowData(
      identifier: identifier,
      identifierType: type,
      phoneVerificationChannel: channel,
    );
    state = NotifierState.loading(data: context);
    // Resetting the remembered account's password retires its saved one;
    // recovering a different account leaves the enrollment alone.
    await ref
        .read(biometricLoginProvider.notifier)
        .forgetEnrollment(onlyForIdentifier: identifier);
    if (operationId != _operationId) return;
    final request = type == IdentifierType.phoneNumber
        ? ForgotRequest.phone(identifier, channel!)
        : ForgotRequest.email(identifier);
    final response = await ref
        .read(authServiceProvider)
        .forgotPassword(request);
    if (operationId != _operationId) return;
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    ref.read(testOtpProvider.notifier).show(TestOtpFlow.passwordRecovery, dto);
    state = NotifierState.done(
      context.copyWith(
        stage: RecoveryFlowStage.awaitingOtp,
        verificationId: dto.verificationId,
        otpExpiresAt: dto.expiresAt,
      ),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> verifyOtp(String otpCode) async {
    final context = state.data;
    if (context?.stage != RecoveryFlowStage.awaitingOtp) {
      _error('Password OTP cannot be verified from this step.');
      return;
    }
    if (!isValidOtpCode(otpCode)) {
      _error('Enter a valid 6-digit code.');
      return;
    }
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.passwordRecovery);
    final operationId = ++_operationId;
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .verifyPasswordOtp(
          VerifyOtpRequest(identifier: context!.identifier, otpCode: otpCode),
        );
    if (operationId != _operationId) return;
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    _resetToken = dto.resetToken;
    state = NotifierState.done(
      context.copyWith(stage: RecoveryFlowStage.awaitingNewSecret),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> reset(String newPassword) async {
    final context = state.data;
    final token = _resetToken;
    if (context == null ||
        context.stage != RecoveryFlowStage.awaitingNewSecret ||
        token == null) {
      _error('The password reset session is no longer available.');
      return;
    }
    if (!isValidApiPassword(newPassword)) {
      _error(
        'Use at least 8 characters with a letter, number, and special character.',
      );
      return;
    }
    final operationId = ++_operationId;
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .resetPassword(
          ResetPasswordRequest(resetToken: token, newPassword: newPassword),
        );
    if (operationId != _operationId) return;
    if (!response.isDone) {
      state = response.failureWith(context);
      return;
    }
    _resetToken = null;
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.passwordRecovery);
    state = NotifierState.done(
      context.copyWith(stage: RecoveryFlowStage.completed),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    ref
        .read(authNavigationProvider.notifier)
        .publish(
          AuthDestination.login,
          mode: AuthNavigationMode.clearStack,
          message: response.message,
          messageTone: AppMessageTone.success,
        );
  }

  void cancel() {
    _operationId += 1;
    _resetToken = null;
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.passwordRecovery);
    state = const NotifierState.idle(data: PasswordRecoveryFlowData());
  }

  void _error(String message) =>
      state = NotifierState.error(message, data: state.data);
}

final pinRecoveryProvider =
    NotifierProvider<PinRecoveryNotifier, NotifierState<PinRecoveryFlowData>>(
      PinRecoveryNotifier.new,
    );

class PinRecoveryNotifier extends Notifier<NotifierState<PinRecoveryFlowData>> {
  String? _resetToken;
  int _operationId = 0;

  @override
  NotifierState<PinRecoveryFlowData> build() {
    ref.onDispose(() {
      _operationId += 1;
      _resetToken = null;
    });
    return const NotifierState.idle(data: PinRecoveryFlowData());
  }

  Future<void> start(
    String rawIdentifier, {
    PhoneVerificationChannel? channel,
  }) async {
    final operationId = ++_operationId;
    final identifier = normalizeIdentifier(rawIdentifier);
    final type = identifierTypeFor(identifier);
    if (!isValidIdentifier(identifier, type)) {
      _error('Enter a valid email or Nigerian phone number.');
      return;
    }
    if (type == IdentifierType.phoneNumber && channel == null) {
      _error('Choose SMS or WhatsApp.');
      return;
    }
    final context = PinRecoveryFlowData(
      identifier: identifier,
      identifierType: type,
      phoneVerificationChannel: channel,
    );
    state = NotifierState.loading(data: context);
    // A PIN reset retires the saved biometric approval PIN.
    await ref.read(biometricApprovalProvider.notifier).wipe();
    if (operationId != _operationId) return;
    final request = type == IdentifierType.phoneNumber
        ? ForgotRequest.phone(identifier, channel!)
        : ForgotRequest.email(identifier);
    final response = await ref.read(authServiceProvider).forgotPin(request);
    if (operationId != _operationId) return;
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    ref.read(testOtpProvider.notifier).show(TestOtpFlow.pinRecovery, dto);
    state = NotifierState.done(
      context.copyWith(
        stage: RecoveryFlowStage.awaitingOtp,
        verificationId: dto.verificationId,
        otpExpiresAt: dto.expiresAt,
      ),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> verifyOtp(String otpCode) async {
    final context = state.data;
    if (context?.stage != RecoveryFlowStage.awaitingOtp) {
      _error('PIN OTP cannot be verified from this step.');
      return;
    }
    if (!isValidOtpCode(otpCode)) {
      _error('Enter a valid 6-digit code.');
      return;
    }
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.pinRecovery);
    final operationId = ++_operationId;
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .verifyPinOtp(
          VerifyOtpRequest(identifier: context!.identifier, otpCode: otpCode),
        );
    if (operationId != _operationId) return;
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    _resetToken = dto.resetToken;
    state = NotifierState.done(
      context.copyWith(stage: RecoveryFlowStage.awaitingNewSecret),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> reset(String newPin) async {
    final context = state.data;
    final token = _resetToken;
    if (context == null ||
        context.stage != RecoveryFlowStage.awaitingNewSecret ||
        token == null) {
      _error('The PIN reset session is no longer available.');
      return;
    }
    if (!isStrongTransactionPin(newPin)) {
      _error('Choose a PIN that is hard to guess.');
      return;
    }
    final operationId = ++_operationId;
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .resetPin(ResetPinRequest(resetToken: token, newPin: newPin));
    if (operationId != _operationId) return;
    if (!response.isDone) {
      state = response.failureWith(context);
      return;
    }
    _resetToken = null;
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.pinRecovery);
    // Clear anything saved since the reset began; the new PIN is not saved.
    await ref.read(biometricApprovalProvider.notifier).wipe();
    if (operationId != _operationId) return;
    state = NotifierState.done(
      context.copyWith(stage: RecoveryFlowStage.completed),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  void cancel() {
    _operationId += 1;
    _resetToken = null;
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.pinRecovery);
    state = const NotifierState.idle(data: PinRecoveryFlowData());
  }

  void _error(String message) =>
      state = NotifierState.error(message, data: state.data);
}
