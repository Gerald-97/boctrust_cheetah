import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/core_api_endpoints.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether a contract is declared at all, whatever this build configures.
FeatureAvailability availabilityOf(FeatureCapability capability) =>
    availabilityFor(
      capabilityRequirements[capability],
      configuredBackends: ApiBackend.values.toSet(),
    );

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
      FeatureCapability.biometricLogin,
    });
  });

  test('the government-ID capability requires both configuration reads', () {
    final operations =
        capabilityRequirements[FeatureCapability.kycGovernmentId]!.operations;
    expect(
      operations,
      containsAll(<ApiOperation>{
        (
          backend: ApiBackend.user,
          method: 'GET',
          path: ApiEndpoints.ownKycStatus,
        ),
        (
          backend: ApiBackend.user,
          method: 'POST',
          path: ApiEndpoints.initiateGovernmentIdVerification,
        ),
        (
          backend: ApiBackend.user,
          method: 'GET',
          path: ApiEndpoints.kycProviderConfig,
        ),
        (
          backend: ApiBackend.user,
          method: 'GET',
          path: ApiEndpoints.governmentIdDocumentTypes,
        ),
      }),
    );
  });

  test('money-moving Core operations are staging-only until G2', () {
    // Transfers and bill payment stay out of release builds until
    // transaction-bound authorization and response semantics are published.
    bool movesMoney(ApiOperation operation) =>
        operation.backend == ApiBackend.core &&
        operation.method == 'POST' &&
        CoreApiEndpoints.moneyMoving.contains(operation.path);

    for (final MapEntry(:key, :value) in capabilityRequirements.entries) {
      if (value.operations.any(movesMoney)) {
        expect(value.stagingOnly, isTrue, reason: '$key moves money');
      }
    }
    for (final capability in [
      FeatureCapability.transfers,
      FeatureCapability.airtime,
      FeatureCapability.data,
      FeatureCapability.bills,
    ]) {
      expect(availabilityOf(capability), FeatureAvailability.unavailable);
    }
  });

  test('Core mobile banking slices are available only in staging', () {
    const slices = [
      FeatureCapability.ownAccountTransfers,
      FeatureCapability.savingsWithdrawals,
      FeatureCapability.boctrustTransfers,
      FeatureCapability.interbankTransfers,
      FeatureCapability.airtime,
      FeatureCapability.data,
      FeatureCapability.bills,
      FeatureCapability.beneficiaries,
    ];
    for (final capability in slices) {
      expect(availabilityOf(capability), FeatureAvailability.unavailable);
      expect(
        availabilityFor(
          capabilityRequirements[capability],
          configuredBackends: ApiBackend.values.toSet(),
          staging: true,
        ),
        FeatureAvailability.available,
        reason: '$capability',
      );
      expect(
        availabilityFor(
          capabilityRequirements[capability],
          configuredBackends: {ApiBackend.user},
          staging: true,
        ),
        FeatureAvailability.unavailable,
        reason: '$capability needs Core',
      );
    }
  });
}
