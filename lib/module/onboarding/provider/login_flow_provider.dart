import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/bootstrap_provider.dart';
import '../../../app/services.dart';
import '../../../helper/device_identity_service.dart';
import '../../../helper/fcm_service.dart';
import '../../../utils/auth_input.dart';
import '../model/auth_enums.dart';
import '../model/auth_flow_models.dart';
import '../model/auth_requests.dart';
import '../model/auth_responses.dart';
import '../model/auth_session.dart';
import '../service/auth_service.dart';
import 'auth_session_provider.dart';
import 'test_otp_provider.dart';

final loginFlowProvider =
    NotifierProvider<LoginFlowNotifier, NotifierState<LoginFlowData>>(
      LoginFlowNotifier.new,
    );

class LoginFlowNotifier extends Notifier<NotifierState<LoginFlowData>> {
  String? _pendingPassword;
  bool _retriedAfterApproval = false;
  bool _newDeviceScreenOpened = false;

  @override
  NotifierState<LoginFlowData> build() {
    ref.onDispose(_clearSecrets);
    return const NotifierState.idle(data: LoginFlowData());
  }

  Future<void> login(String rawIdentifier, String password) async {
    final identifier = normalizeIdentifier(rawIdentifier);
    final type = identifierTypeFor(identifier);
    _pendingPassword = password;
    _retriedAfterApproval = false;
    _newDeviceScreenOpened = false;
    final context = LoginFlowData(
      stage: LoginFlowStage.submitting,
      identifier: identifier,
      identifierType: type,
    );
    if (!isValidIdentifier(identifier, type) || password.isEmpty) {
      _clearSecrets();
      state = NotifierState.error(
        'Enter a valid email or Nigerian phone number and password.',
        data: context.copyWith(stage: LoginFlowStage.idle),
      );
      return;
    }
    state = NotifierState.loading(data: context);
    await _submitLogin(context);
  }

  Future<void> _submitLogin(LoginFlowData context) async {
    final password = _pendingPassword;
    if (password == null) {
      _localError('Login credentials are no longer available.');
      return;
    }
    late final String deviceToken;
    try {
      deviceToken = await ref.read(deviceIdentityServiceProvider).getOrCreate();
    } catch (_) {
      _clearSecrets();
      _localError('Unable to create a secure device identity. Please retry.');
      return;
    }
    final response = await ref
        .read(authServiceProvider)
        .login(
          LoginRequest(
            identifier: context.identifier,
            password: password,
            deviceToken: deviceToken,
          ),
        );

    if (response.errorCode == 'NEW_DEVICE_VERIFICATION_REQUIRED' &&
        !_retriedAfterApproval) {
      if (context.identifierType == IdentifierType.phoneNumber) {
        state = NotifierState.done(
          context.copyWith(stage: LoginFlowStage.choosingNewDeviceChannel),
          message: response.message,
          statusCode: response.statusCode,
        );
        _openNewDeviceScreen();
      } else {
        await _requestNewDeviceOtp(
          context.copyWith(stage: LoginFlowStage.requestingNewDeviceOtp),
          failureContext: context.copyWith(stage: LoginFlowStage.idle),
          clearPasswordOnFailure: true,
        );
      }
      return;
    }

    final dto = response.data;
    if (!response.isDone || dto == null) {
      _clearSecrets();
      state = _failure(response, context.copyWith(stage: LoginFlowStage.idle));
      return;
    }
    await _establishSession(dto, context);
  }

  Future<void> chooseNewDeviceChannel(PhoneVerificationChannel channel) async {
    final context = state.data;
    if (context == null ||
        context.stage != LoginFlowStage.choosingNewDeviceChannel) {
      _localError('A delivery channel cannot be selected from this step.');
      return;
    }
    await _requestNewDeviceOtp(
      context.copyWith(
        stage: LoginFlowStage.requestingNewDeviceOtp,
        phoneVerificationChannel: channel,
      ),
      failureContext: context,
    );
  }

  Future<void> resendNewDeviceOtp() async {
    final context = state.data;
    if (context == null ||
        context.stage != LoginFlowStage.awaitingNewDeviceOtp) {
      _localError('A new-device code cannot be resent from this step.');
      return;
    }
    await _requestNewDeviceOtp(
      context.copyWith(stage: LoginFlowStage.requestingNewDeviceOtp),
      failureContext: context,
    );
  }

  Future<void> _requestNewDeviceOtp(
    LoginFlowData context, {
    required LoginFlowData failureContext,
    bool clearPasswordOnFailure = false,
  }) async {
    state = NotifierState.loading(data: context);
    final request = context.identifierType == IdentifierType.phoneNumber
        ? RequestOtpRequest.phone(
            context.identifier,
            OtpPurpose.newDeviceLogin,
            context.phoneVerificationChannel!,
          )
        : RequestOtpRequest.email(
            context.identifier,
            OtpPurpose.newDeviceLogin,
          );
    final response = await ref.read(authServiceProvider).requestOtp(request);
    final dto = response.data;
    if (!response.isDone || dto == null) {
      if (clearPasswordOnFailure) _clearSecrets();
      state = _failure(response, failureContext);
      return;
    }
    ref
        .read(testOtpProvider.notifier)
        .show(TestOtpFlow.newDeviceLogin, dto.otp);
    state = NotifierState.done(
      context.copyWith(
        stage: LoginFlowStage.awaitingNewDeviceOtp,
        verificationId: dto.otp.verificationId,
        otpExpiresAt: dto.otp.expiresAt,
      ),
      message: response.message,
      statusCode: response.statusCode,
      meta: response.meta,
    );
    _openNewDeviceScreen();
  }

  Future<void> verifyNewDevice(String otpCode) async {
    final context = state.data;
    if (context == null ||
        context.stage != LoginFlowStage.awaitingNewDeviceOtp ||
        _retriedAfterApproval) {
      _localError('New-device verification cannot run from this step.');
      return;
    }
    if (!isValidOtpCode(otpCode)) {
      _localError('Enter a valid 6-digit code.');
      return;
    }
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.newDeviceLogin);
    state = NotifierState.loading(
      data: context.copyWith(stage: LoginFlowStage.verifyingNewDevice),
    );
    late final String deviceToken;
    try {
      deviceToken = await ref.read(deviceIdentityServiceProvider).getOrCreate();
    } catch (_) {
      state = NotifierState.error(
        'Unable to read the secure device identity. Please retry.',
        data: context,
      );
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
        .verifyNewDevice(
          VerifyNewDeviceRequest(
            identifier: context.identifier,
            otpCode: otpCode,
            deviceToken: deviceToken,
            fcmToken: fcmToken,
          ),
        );
    if (!response.isDone) {
      state = _failure(response, context);
      return;
    }
    _retriedAfterApproval = true;
    final retryContext = context.copyWith(
      stage: LoginFlowStage.retryingAfterDeviceApproval,
    );
    state = NotifierState.loading(data: retryContext);
    await _submitLogin(retryContext);
  }

  Future<void> _establishSession(LoginData dto, LoginFlowData context) async {
    if (dto.expiresInSeconds <= 0 ||
        dto.user.identifierType == IdentifierType.unknown) {
      _clearSecrets();
      _localError('The login session returned by the server was invalid.');
      return;
    }
    final expiresAt = DateTime.now().toUtc().add(
      Duration(milliseconds: (dto.expiresInSeconds * 1000).round()),
    );
    final established = await ref
        .read(authSessionProvider.notifier)
        .establish(
          AuthSession(
            accessToken: dto.accessToken,
            expiresAt: expiresAt,
            userId: dto.user.userId,
            email: dto.user.email,
            phoneNumber: dto.user.phoneNumber,
            identifierType: dto.user.identifierType,
          ),
        );
    if (!established) {
      _clearSecrets();
      _localError('Unable to save your login session. Please try again.');
      return;
    }

    _clearSecrets();
    state = NotifierState.done(
      context.copyWith(stage: LoginFlowStage.completed),
    );
    await ref.read(startupGateProvider.notifier).startAfterLogin();
  }

  void cancel() {
    _clearSecrets();
    ref.read(testOtpProvider.notifier).clear(TestOtpFlow.newDeviceLogin);
    _newDeviceScreenOpened = false;
    state = const NotifierState.idle(data: LoginFlowData());
  }

  void _openNewDeviceScreen() {
    if (_newDeviceScreenOpened) return;
    final alreadyQueued = ref
        .read(authNavigationProvider)
        .any((intent) => intent.destination == AuthDestination.newDeviceOtp);
    _newDeviceScreenOpened = true;
    if (alreadyQueued) return;
    ref
        .read(authNavigationProvider.notifier)
        .publish(AuthDestination.newDeviceOtp, mode: AuthNavigationMode.push);
  }

  NotifierState<LoginFlowData> _failure<T>(
    NotifierState<T> source,
    LoginFlowData context,
  ) => NotifierState.error(
    source.message ?? 'Request failed.',
    data: context,
    statusCode: source.statusCode,
    errorCode: source.errorCode,
    errors: source.errors,
    meta: source.meta,
    noAuth: source.noAuth,
  );

  void _localError(String message) {
    state = NotifierState.error(message, data: state.data);
  }

  void _clearSecrets() {
    _pendingPassword = null;
  }
}
