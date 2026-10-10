import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/core_api_endpoints.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      FeatureCapability.coreAccountHistory,
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
  test('scan to pay needs Core name enquiry in staging, not remote OCR', () {
    final requirement = capabilityRequirements[FeatureCapability.scanToPay]!;
    expect(requirement.operations, {
      (
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankNameEnquiry,
      ),
    });
    expect(
      availabilityFor(
        requirement,
        configuredBackends: {ApiBackend.user},
        staging: true,
      ),
      FeatureAvailability.unavailable,
    );
    expect(
      availabilityFor(
        requirement,
        configuredBackends: ApiBackend.values.toSet(),
      ),
      FeatureAvailability.unavailable,
    );
  });

  group('transfer authorization readiness', () {
    test('is on in staging builds only', () {
      bool ready({required bool staging}) {
        final container = ProviderContainer(
          overrides: [stagingModeProvider.overrideWithValue(staging)],
        );
        addTearDown(container.dispose);
        return container.read(transferAuthorizationReadyProvider);
      }

      expect(ready(staging: true), isTrue);
      expect(ready(staging: false), isFalse);
    });

    test('production stays unavailable even when evidence is ready', () {
      expect(
        transferAuthorizationReady(evidenceReady: true, staging: false),
        isFalse,
      );
      expect(
        transferAuthorizationReady(evidenceReady: true, staging: true),
        isTrue,
      );
      expect(
        transferAuthorizationReady(evidenceReady: false, staging: true),
        isFalse,
      );
    });
  });
  test('live re-queries are Core reads, never money-moving', () {
    final interbank =
        capabilityRequirements[FeatureCapability.interbankTransfers]!
            .operations;
    expect(
      interbank,
      contains((
        backend: ApiBackend.core,
        method: 'POST',
        path: CoreApiEndpoints.interbankTransferRequeryTemplate,
      )),
    );
    for (final capability in [
      FeatureCapability.ownAccountTransfers,
      FeatureCapability.savingsWithdrawals,
      FeatureCapability.boctrustTransfers,
    ]) {
      expect(
        capabilityRequirements[capability]!.operations,
        contains((
          backend: ApiBackend.core,
          method: 'POST',
          path: CoreApiEndpoints.intrabankTransferRequeryTemplate,
        )),
      );
    }
    expect(
      CoreApiEndpoints.moneyMoving,
      isNot(
        anyOf(
          contains(CoreApiEndpoints.interbankTransferRequeryTemplate),
          contains(CoreApiEndpoints.intrabankTransferRequeryTemplate),
        ),
      ),
    );
  });
}
