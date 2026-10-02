import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_configuration_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// A staging build, so a `sandbox` provider configuration is accepted.
final Override stagingBuildOverride = appBuildEnvironmentProvider
    .overrideWithValue((isStaging: true, isProd: false));

Map<String, Object?> _operation(String provider, {required bool identity}) => {
  'provider': provider,
  'product': identity ? 'bvn_selfie' : 'government_id_verification',
  'sdkJobType': identity ? 'dojahBvnSelfie' : 'dojahGovernmentId',
  'jobType': identity ? 'identity' : 'government_id',
  'callbackUrl': null,
};

/// The live provider configuration: Dojah for both operations, sandbox.
KycProviderConfigData kycConfigFixture({
  String activeProvider = 'dojah',
  String governmentIdProvider = 'dojah',
}) => KycProviderConfigData.fromJson({
  'activeProvider': activeProvider,
  'environment': 'sandbox',
  'identity': _operation(activeProvider, identity: true),
  'governmentId': _operation(governmentIdProvider, identity: false),
});

Map<String, Object?> documentRow(
  String value,
  String label, {
  bool requiresDocumentNumber = false,
}) => {
  'value': value,
  'label': label,
  'description': '',
  'requiresDocumentNumber': requiresDocumentNumber,
  'active': true,
};

/// The live catalogue, in server order.
GovernmentIdDocumentCatalogue documentCatalogueFixture([
  List<Map<String, Object?>>? rows,
]) => GovernmentIdDocumentCatalogue.fromJson({
  'documentTypes':
      rows ??
      [
        documentRow('international_passport', 'International Passport'),
        documentRow('drivers_license', "Driver's License"),
        documentRow('voter_id', "Voter's Card"),
        documentRow('national_id', 'National ID'),
        documentRow('nin_slip', 'NIN Slip', requiresDocumentNumber: true),
      ],
});

/// Serves the default configuration fixtures from a fake [KycService].
mixin KycConfigurationFixture on KycService {
  KycProviderConfigData get providerConfigFixture => kycConfigFixture();
  GovernmentIdDocumentCatalogue get catalogueFixture =>
      documentCatalogueFixture();

  @override
  Future<NotifierState<KycProviderConfigData>> getProviderConfig() async =>
      NotifierState.done(providerConfigFixture);

  @override
  Future<NotifierState<GovernmentIdDocumentCatalogue>>
  getGovernmentIdDocumentTypes() async => NotifierState.done(catalogueFixture);
}
