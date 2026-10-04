import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../utils/auth_input.dart';
import '../../account/provider/user_providers.dart';
import '../../home/provider/home_provider.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../service/auth_service.dart';
import 'test_otp_provider.dart';

final identifierVerificationProvider =
    NotifierProvider<
      IdentifierVerificationNotifier,
      NotifierState<IdentifierVerificationFlowData>
    >(IdentifierVerificationNotifier.new);

class IdentifierVerificationNotifier
    extends Notifier<NotifierState<IdentifierVerificationFlowData>> {
  @override
  NotifierState<IdentifierVerificationFlowData> build() =>
      const NotifierState.idle(data: IdentifierVerificationFlowData());

  Future<void> initiateEmail(String rawEmail) async {
    final email = normalizeEmailAddress(rawEmail);
    await _initiate(
      EmailIdentifierVerificationRequest(email),
      email,
      IdentifierType.email,
      null,
    );
  }

  Future<void> initiatePhone(
    String rawPhone,
    PhoneVerificationChannel channel,
  ) async {
    final phone = normalizeNigerianPhone(rawPhone);
    await _initiate(
      PhoneIdentifierVerificationRequest(phoneNumber: phone, channel: channel),
      phone,
      IdentifierType.phoneNumber,
      channel,
    );
  }

  Future<void> _initiate(
    InitiateIdentifierVerificationRequest request,
    String identifier,
    IdentifierType type,
    PhoneVerificationChannel? channel,
  ) async {
    final context = IdentifierVerificationFlowData(
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
    final response = await ref
        .read(authServiceProvider)
        .initiateIdentifierVerification(request);
    final dto = response.data;
    if (!response.isDone || dto == null) {
      state = response.failureWith(context);
      return;
    }
    ref
        .read(testOtpProvider.notifier)
        .show(TestOtpFlow.identifierVerification, dto.otp);
    state = NotifierState.done(
      context.copyWith(
        stage: IdentifierVerificationStage.awaitingOtp,
        verificationId: dto.otp.verificationId,
        otpExpiresAt: dto.otp.expiresAt,
      ),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
  }

  Future<void> verify(String otpCode) async {
    final context = state.data;
    if (context?.stage != IdentifierVerificationStage.awaitingOtp) {
      state = NotifierState.error(
        'Identifier verification cannot run from this step.',
        data: context,
      );
      return;
    }
    if (!isValidOtpCode(otpCode)) {
      state = NotifierState.error('Enter a valid 6-digit code.', data: context);
      return;
    }
    ref
        .read(testOtpProvider.notifier)
        .clear(TestOtpFlow.identifierVerification);
    state = NotifierState.loading(data: context);
    final response = await ref
        .read(authServiceProvider)
        .verifyIdentifier(
          VerifyOtpRequest(identifier: context!.identifier, otpCode: otpCode),
        );
    if (!response.isDone) {
      state = response.failureWith(context);
      return;
    }
    state = NotifierState.done(
      context.copyWith(stage: IdentifierVerificationStage.completed),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    ref
        .read(testOtpProvider.notifier)
        .clear(TestOtpFlow.identifierVerification);
    // The verified email or phone, and anything gated on it (Home's next
    // action, tier requirements), only show once these are reloaded.
    unawaited(
      Future.wait([
        ref.read(userProfileProvider.notifier).load(),
        ref.read(userTierProvider.notifier).load(),
        ref.read(userHomeProvider.notifier).load(),
      ]),
    );
  }
}
