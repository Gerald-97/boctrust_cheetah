import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/interceptors.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/auth_requests.dart';
import '../model/auth_responses.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(apiServiceProvider)),
);

class AuthService {
  const AuthService(this._api);
  final ApiService _api;

  Future<NotifierState<SignupData>> signup(SignupRequest request) =>
      _post(ApiEndpoints.signup, request, SignupData.fromJson);

  Future<NotifierState<RequestOtpData>> requestOtp(RequestOtpRequest request) =>
      _post(ApiEndpoints.requestOtp, request, RequestOtpData.fromJson);

  Future<NotifierState<EmptyData>> verifyAccount(
    VerifyAccountRequest request,
  ) => _post(ApiEndpoints.verifyAccount, request, EmptyData.fromJson);

  Future<NotifierState<CreateFirstPasswordData>> createFirstPassword(
    CreateFirstPasswordRequest request,
  ) => _post(
    ApiEndpoints.createFirstPassword,
    request,
    CreateFirstPasswordData.fromJson,
  );

  Future<NotifierState<OtpData>> forgotPassword(ForgotRequest request) =>
      _post(ApiEndpoints.forgotPassword, request, OtpData.fromJson);

  Future<NotifierState<ResetTokenData>> verifyPasswordOtp(
    VerifyOtpRequest request,
  ) => _post(ApiEndpoints.verifyPasswordOtp, request, ResetTokenData.fromJson);

  Future<NotifierState<EmptyData>> resetPassword(
    ResetPasswordRequest request,
  ) => _post(ApiEndpoints.resetPassword, request, EmptyData.fromJson);

  Future<NotifierState<EmptyData>> changePassword(
    ChangePasswordRequest request,
  ) => _post(ApiEndpoints.changePassword, request, EmptyData.fromJson);

  Future<NotifierState<OtpData>> forgotPin(ForgotRequest request) =>
      _post(ApiEndpoints.forgotPin, request, OtpData.fromJson);

  Future<NotifierState<ResetTokenData>> verifyPinOtp(
    VerifyOtpRequest request,
  ) => _post(ApiEndpoints.verifyPinOtp, request, ResetTokenData.fromJson);

  Future<NotifierState<EmptyData>> resetPin(ResetPinRequest request) =>
      _post(ApiEndpoints.resetPin, request, EmptyData.fromJson);

  Future<NotifierState<CreateFirstPinData>> createFirstPin(
    CreateFirstPinRequest request,
  ) => _post(ApiEndpoints.createFirstPin, request, CreateFirstPinData.fromJson);

  Future<NotifierState<EmptyData>> changePin(ChangePinRequest request) =>
      _post(ApiEndpoints.changePin, request, EmptyData.fromJson);

  Future<NotifierState<LoginData>> login(LoginRequest request) =>
      _post(ApiEndpoints.login, request, LoginData.fromJson);

  Future<NotifierState<EmptyData>> verifyCurrentPassword(
    VerifyCurrentPasswordRequest request,
  ) => _post(ApiEndpoints.verifyCurrentPassword, request, EmptyData.fromJson);

  Future<NotifierState<EmptyData>> verifyCurrentPin(
    VerifyCurrentPinRequest request,
  ) => _post(ApiEndpoints.verifyCurrentPin, request, EmptyData.fromJson);

  Future<NotifierState<EmptyData>> verifyNewDevice(
    VerifyNewDeviceRequest request,
  ) => _post(ApiEndpoints.verifyDevice, request, EmptyData.fromJson);

  Future<NotifierState<EmptyData>> updateFcmToken(
    UpdateFcmTokenRequest request,
  ) async => NotifierState.fromResponse(
    await _api.patchData<EmptyData>(
      ApiEndpoints.fcmToken,
      data: request.toJson(),
      parser: EmptyData.fromJson,
    ),
  );

  /// Revokes [accessToken] server-side. The token is passed in because the
  /// local session is already cleared by the time this request is sent.
  Future<NotifierState<EmptyData>> logout({
    required String accessToken,
  }) async => NotifierState.fromResponse(
    await _api.postData<EmptyData>(
      ApiEndpoints.logout,
      parser: EmptyData.fromJson,
      requestExtra: {
        'suppressSessionExpiry': true,
        AuthInterceptor.pinnedAccessTokenKey: accessToken,
      },
    ),
  );

  Future<NotifierState<IdentifierVerificationInitiateData>>
  initiateIdentifierVerification(
    InitiateIdentifierVerificationRequest request,
  ) => _post(
    ApiEndpoints.initiateIdentifierVerification,
    request,
    IdentifierVerificationInitiateData.fromJson,
  );

  Future<NotifierState<IdentifierVerificationVerifyData>> verifyIdentifier(
    VerifyOtpRequest request,
  ) => _post(
    ApiEndpoints.verifyIdentifier,
    request,
    IdentifierVerificationVerifyData.fromJson,
  );

  Future<NotifierState<T>> _post<T>(
    String endpoint,
    JsonRequest request,
    T Function(Object?) parser,
  ) async => NotifierState.fromResponse(
    await _api.postData<T>(endpoint, data: request.toJson(), parser: parser),
  );
}
