import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
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
}
