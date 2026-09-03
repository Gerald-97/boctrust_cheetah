import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../../onboarding/model/auth_responses.dart' show EmptyData;
import '../model/kyc_models.dart';

final kycServiceProvider = Provider<KycService>(
  (ref) => KycService(ref.watch(apiServiceProvider)),
);

class KycService {
  const KycService(this._api);
  final ApiService _api;

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
  Future<NotifierState<EmptyData>> completeUtilityBillUpload(
    String verificationId,
  ) async => NotifierState.fromResponse(
    await _api.postData<EmptyData>(
      ApiEndpoints.completeUtilityBillUpload(verificationId),
      parser: (_) => const EmptyData(),
    ),
  );
}
