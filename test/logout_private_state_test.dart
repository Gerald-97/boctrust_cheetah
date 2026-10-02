import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_configuration_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/security_action_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Kyc extends KycService {
  _Kyc() : super(ApiService(Dio()));

  @override
  Future<NotifierState<KycStatusData>> getStatus() async => NotifierState.done(
    KycStatusData.fromJson({
      'identity': {'status': 'pending', 'identityLast4': '0006'},
    }),
  );

  @override
  Future<NotifierState<GovernmentIdDocumentCatalogue>>
  getGovernmentIdDocumentTypes() async => NotifierState.done(
    GovernmentIdDocumentCatalogue.fromJson({
      'documentTypes': [
        {
          'value': 'national_id',
          'label': 'National ID',
          'description': '',
          'requiresDocumentNumber': false,
          'active': true,
        },
      ],
    }),
  );
}

void main() {
  test('logging out drops the previous user KYC status', () async {
    final container = ProviderContainer(
      overrides: [kycServiceProvider.overrideWithValue(_Kyc())],
    );
    addTearDown(container.dispose);
    await container.read(kycStatusProvider.notifier).load();
    expect(
      container.read(kycStatusProvider).data?.identity.identityLast4,
      '0006',
    );

    await container.read(logoutProvider.notifier).logout();

    expect(container.read(kycStatusProvider).data, isNull);
  });

  test('logging out drops the government-ID document catalogue', () async {
    final container = ProviderContainer(
      overrides: [kycServiceProvider.overrideWithValue(_Kyc())],
    );
    addTearDown(container.dispose);
    await container.read(governmentIdDocumentTypesProvider.notifier).load();
    expect(container.read(governmentIdDocumentTypesProvider).data, isNotNull);

    await container.read(logoutProvider.notifier).logout();

    expect(container.read(governmentIdDocumentTypesProvider).data, isNull);
  });
}
