import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only capabilities with a declared live contract are available', () {
    final available = {
      for (final capability in FeatureCapability.values)
        if (availabilityOf(capability) == FeatureAvailability.available)
          capability,
    };

    // Adding to this set means a new endpoint, typed models, service and
    // provider all landed together; flipping anything else on is a bug.
    expect(available, {
      FeatureCapability.flexSavingsView,
      FeatureCapability.savingsCatalogueView,
      FeatureCapability.linkedBanksView,
      FeatureCapability.linkedBanksManage,
      FeatureCapability.kycIdentity,
      FeatureCapability.kycGovernmentId,
      FeatureCapability.kycUtilityBill,
      FeatureCapability.passwordPinControls,
      FeatureCapability.notificationPreferences,
      FeatureCapability.accessibilityPreferences,
    });
  });

  test('the government-ID capability requires both configuration reads', () {
    final operations =
        capabilityRequirements[FeatureCapability.kycGovernmentId]!.operations;
    expect(
      operations,
      containsAll(<ApiOperation>{
        (method: 'GET', path: ApiEndpoints.ownKycStatus),
        (method: 'POST', path: ApiEndpoints.initiateGovernmentIdVerification),
        (method: 'GET', path: ApiEndpoints.kycProviderConfig),
        (method: 'GET', path: ApiEndpoints.governmentIdDocumentTypes),
      }),
    );
  });
}
