import 'dart:async';

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
  Completer<LoginAttemptResult>? _attempt;
  String _attemptIdentifier = '';

  @override
  NotifierState<LoginFlowData> build() {
    ref.onDispose(() {
      _clearSecrets();
      _finish(LoginAttemptOutcome.cancelled);
    });
    return const NotifierState.idle(data: LoginFlowData());
  }

  /// Resolves once the attempt ends: after session establishment, a terminal
  /// failure, or cancellation. New-device verification keeps it pending.
  Future<LoginAttemptResult> login(String rawIdentifier, String password) {
    final identifier = normalizeIdentifier(rawIdentifier);
    if (_attempt != null) {
      _localError('A sign-in is already in progress.');
      return Future.value(
        LoginAttemptResult(
          outcome: LoginAttemptOutcome.requestFailure,
          identifier: identifier,
          message: 'A sign-in is already in progress.',
        ),
      );
    }
    final attempt = Completer<LoginAttemptResult>();
    _attempt = attempt;
    _attemptIdentifier = identifier;
    unawaited(_start(identifier, password));
    return attempt.future;
  }

  Future<void> _start(String identifier, String password) async {
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
      _finish(LoginAttemptOutcome.invalidInput);
      return;
    }
    state = NotifierState.loading(data: context);
    await _submitLogin(context);
  }

  Future<void> _submitLogin(LoginFlowData context) async {
    final password = _pendingPassword;
    if (password == null) {
      _localError('Login credentials are no longer available.');
      _finish(LoginAttemptOutcome.requestFailure);
      return;
    }
    late final String deviceToken;
    try {
      deviceToken = await ref.read(deviceIdentityServiceProvider).getOrCreate();
    } catch (_) {
      _clearSecrets();
      _localError('Unable to create a secure device identity. Please retry.');
      _finish(LoginAttemptOutcome.deviceIdentityFailure);
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
      _finish(
        response.noAuth || response.statusCode == 401
            ? LoginAttemptOutcome.invalidCredentials
            : LoginAttemptOutcome.requestFailure,
      );
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
      state = _failure(response, failureContext);
      // Without the password the attempt cannot continue.
      if (clearPasswordOnFailure) {
        _clearSecrets();
        _finish(LoginAttemptOutcome.requestFailure);
      }
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
      _finish(LoginAttemptOutcome.requestFailure);
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
      _finish(LoginAttemptOutcome.requestFailure);
      return;
    }

    _clearSecrets();
    state = NotifierState.done(
      context.copyWith(stage: LoginFlowStage.completed),
    );
    try {
      await ref.read(startupGateProvider.notifier).startAfterLogin();
    } finally {
      _finish(LoginAttemptOutcome.completed);
    }
  }

  void cancel() {
    _clearSecrets();
    _finish(LoginAttemptOutcome.cancelled);
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

  /// Resolves the active attempt exactly once; later calls are ignored.
  void _finish(LoginAttemptOutcome outcome) {
    final attempt = _attempt;
    if (attempt == null) return;
    _attempt = null;
    final message =
        outcome == LoginAttemptOutcome.completed ||
            outcome == LoginAttemptOutcome.cancelled
        ? null
        : state.message;
    attempt.complete(
      LoginAttemptResult(
        outcome: outcome,
        identifier: _attemptIdentifier,
        message: message,
      ),
    );
  }
}
