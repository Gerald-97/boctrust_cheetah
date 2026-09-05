import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/kyc_models.dart';
import '../model/kyc_status_models.dart';

final kycServiceProvider = Provider<KycService>(
  (ref) => KycService(ref.watch(apiServiceProvider)),
);

class KycService {
  const KycService(this._api);
  final ApiService _api;

  /// The authoritative view of this user's verification state.
  ///
  /// Initiation and SDK submission never mean verified; this operation and the
  /// refreshed tier/profile/Home aggregates do.
  Future<NotifierState<KycStatusData>> getStatus() async =>
      NotifierState.fromResponse(
        await _api.getData<KycStatusData>(
          ApiEndpoints.ownKycStatus,
          parser: KycStatusData.fromJson,
        ),
      );

  Future<NotifierState<KycInitiationData>> initiateIdentity(
    IdentityVerificationRequest request,
  ) async => NotifierState.fromResponse(
    await _api.postData<KycInitiationData>(
      ApiEndpoints.initiateIdentityVerification,
      data: request.toJson(),
      parser: KycInitiationData.fromJson,
    ),
  );

  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) async => NotifierState.fromResponse(
    await _api.postData<KycInitiationData>(
      ApiEndpoints.initiateGovernmentIdVerification,
      data: request.toJson(),
      parser: KycInitiationData.fromJson,
    ),
  );

  Future<NotifierState<UtilityBillUploadTarget>> initiateUtilityBillUpload(
    UtilityBillInitiationRequest request,
  ) async => NotifierState.fromResponse(
    await _api.postData<UtilityBillUploadTarget>(
      ApiEndpoints.initiateUtilityBillUpload,
      data: request.toJson(),
      parser: UtilityBillUploadTarget.fromJson,
    ),
  );

  /// Confirms the bytes were uploaded, moving the verification to review.
  Future<NotifierState<UtilityBillCompletionData>> completeUtilityBillUpload(
    String verificationId,
  ) async => NotifierState.fromResponse(
    await _api.postData<UtilityBillCompletionData>(
      ApiEndpoints.completeUtilityBillUpload(verificationId),
      parser: UtilityBillCompletionData.fromJson,
    ),
  );
}
