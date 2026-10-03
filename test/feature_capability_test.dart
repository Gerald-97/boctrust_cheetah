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

  test('no capability depends on a Core money-moving operation', () {
    // Transfers, transfer status and bill payment stay unavailable until
    // transaction-bound authorization and response semantics are published.
    bool movesMoney(ApiOperation operation) =>
        operation.backend == ApiBackend.core &&
        (operation.path == CoreApiEndpoints.ownAccountTransfer ||
            operation.path == CoreApiEndpoints.intrabankWithdrawals);

    for (final MapEntry(:key, :value) in capabilityRequirements.entries) {
      expect(
        value.operations.where(movesMoney),
        isEmpty,
        reason: '$key must not require a money-moving Core operation',
      );
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

  test(
    'mobile banking capabilities stay unavailable until their slice ships',
    () {
      for (final capability in [
        FeatureCapability.ownAccountTransfers,
        FeatureCapability.savingsWithdrawals,
      ]) {
        expect(
          availabilityOf(capability),
          FeatureAvailability.unavailable,
          reason: '$capability has no registered contract yet',
        );
      }
    },
  );
}
