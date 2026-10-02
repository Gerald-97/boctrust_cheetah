import 'dart:async';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_configuration_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _operation = KycProviderOperationConfig(
  provider: KycProvider.dojah,
  product: 'government_id_verification',
  sdkJobType: 'dojahGovernmentId',
  jobType: 'government_id',
);

KycProviderConfigData _config(KycProviderEnvironment environment) =>
    KycProviderConfigData(
      activeProvider: KycProvider.dojah,
      environment: environment,
      identity: _operation,
      governmentId: _operation,
    );

class _Kyc extends KycService {
  _Kyc() : super(ApiService(Dio()));

  Completer<NotifierState<KycProviderConfigData>> config = Completer();
  int configCalls = 0;

  @override
  Future<NotifierState<KycProviderConfigData>> getProviderConfig() {
    configCalls++;
    return config.future;
  }
}

ProviderContainer _container(_Kyc kyc) {
  final container = ProviderContainer(
    overrides: [kycServiceProvider.overrideWithValue(kyc)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the app environment must match the provider environment', () {
    // The test build runs neither ENV=staging nor ENV=prod, so every
    // environment is a mismatch here; the pairing itself is pinned below.
    expect(
      providerEnvironmentMatches(
        KycProviderEnvironment.sandbox,
        isStaging: true,
        isProd: false,
      ),
      isTrue,
    );
    expect(
      providerEnvironmentMatches(
        KycProviderEnvironment.live,
        isStaging: false,
        isProd: true,
      ),
      isTrue,
    );
    expect(
      providerEnvironmentMatches(
        KycProviderEnvironment.live,
        isStaging: true,
        isProd: false,
      ),
      isFalse,
    );
    expect(
      providerEnvironmentMatches(
        KycProviderEnvironment.sandbox,
        isStaging: false,
        isProd: true,
      ),
      isFalse,
    );
  });

  test('a mismatched environment loads as an error', () async {
    final kyc = _Kyc();
    final container = _container(kyc);
    kyc.config.complete(
      NotifierState.done(_config(KycProviderEnvironment.live)),
    );

    // Tests run with no ENV, so even sandbox is a mismatch.
    await container.read(kycProviderConfigProvider.notifier).load();

    final state = container.read(kycProviderConfigProvider);
    expect(state.isError, isTrue);
    expect(state.data, isNull);
  });

  test('overlapping loads share one request', () async {
    final kyc = _Kyc();
    final notifier = _container(kyc).read(kycProviderConfigProvider.notifier);

    final first = notifier.load();
    final second = notifier.load();
    kyc.config.complete(
      NotifierState.done(_config(KycProviderEnvironment.sandbox)),
    );
    await Future.wait([first, second]);

    expect(kyc.configCalls, 1);
  });

  test('a response landing after clear cannot repopulate state', () async {
    final kyc = _Kyc();
    final container = _container(kyc);
    final pending = container.read(kycProviderConfigProvider.notifier).load();

    container.read(kycProviderConfigProvider.notifier).clear();
    kyc.config.complete(
      NotifierState.done(_config(KycProviderEnvironment.sandbox)),
    );
    await pending;

    expect(
      container.read(kycProviderConfigProvider).status,
      ServiceStatus.idle,
    );
  });
}
