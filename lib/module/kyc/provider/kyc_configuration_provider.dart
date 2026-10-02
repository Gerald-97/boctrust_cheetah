import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/kyc_configuration_models.dart';
import '../service/kyc_service.dart';

const _configurationUnavailable =
    'Verification is not available right now. Please try again.';

/// Whether the provider environment the backend reports belongs to this
/// build: staging accepts only `sandbox`, production only `live`. Anything
/// else blocks initiation.
bool providerEnvironmentMatches(
  KycProviderEnvironment environment, {
  required bool isStaging,
  required bool isProd,
}) => switch (environment) {
  KycProviderEnvironment.sandbox => isStaging,
  KycProviderEnvironment.live => isProd,
};

typedef AppBuildEnvironment = ({bool isStaging, bool isProd});

/// The build's own environment, overridable in tests that cannot set ENV.
final appBuildEnvironmentProvider = Provider<AppBuildEnvironment>(
  (ref) => (isStaging: Env.isStaging, isProd: Env.isProd),
);

final kycProviderConfigProvider =
    NotifierProvider<
      KycProviderConfigNotifier,
      NotifierState<KycProviderConfigData>
    >(KycProviderConfigNotifier.new);

final governmentIdDocumentTypesProvider =
    NotifierProvider<
      GovernmentIdDocumentTypesNotifier,
      NotifierState<GovernmentIdDocumentCatalogue>
    >(GovernmentIdDocumentTypesNotifier.new);

/// Session-scoped, refreshable KYC configuration. Never persisted.
///
/// Overlapping loads share one request, a failed refresh keeps the last good
/// data beside the error, and [clear] drops both state and any in-flight
/// response so a previous session's answer can never reappear.
abstract class _KycConfigurationNotifier<T> extends Notifier<NotifierState<T>>
    with StaleResultGuard<NotifierState<T>> {
  Future<NotifierState<T>>? _inFlight;

  Future<NotifierState<T>> fetch(KycService service);

  /// The published result, or an error when [data] must not authorize a form.
  NotifierState<T> validate(NotifierState<T> result) => result;

  @override
  NotifierState<T> build() {
    trackDisposal();
    return const NotifierState.idle();
  }

  Future<NotifierState<T>> load() => _inFlight ??= _load();

  Future<NotifierState<T>> _load() async {
    final token = beginRequest();
    final retained = state.data;
    state = NotifierState.loading(data: retained);
    try {
      final result = validate(await fetch(ref.read(kycServiceProvider)));
      if (!isCurrent(token)) return result;
      state = result.isError && retained != null
          ? NotifierState.error(
              result.message ?? _configurationUnavailable,
              data: retained,
              statusCode: result.statusCode,
            )
          : result;
      return state;
    } finally {
      if (isCurrent(token)) _inFlight = null;
    }
  }

  void clear() {
    beginRequest();
    _inFlight = null;
    state = const NotifierState.idle();
  }
}

class KycProviderConfigNotifier
    extends _KycConfigurationNotifier<KycProviderConfigData> {
  @override
  Future<NotifierState<KycProviderConfigData>> fetch(KycService service) =>
      service.getProviderConfig();

  @override
  NotifierState<KycProviderConfigData> validate(
    NotifierState<KycProviderConfigData> result,
  ) {
    final data = result.data;
    if (data == null || result.isError) return result;
    final build = ref.read(appBuildEnvironmentProvider);
    final matches = providerEnvironmentMatches(
      data.environment,
      isStaging: build.isStaging,
      isProd: build.isProd,
    );
    return matches
        ? result
        : const NotifierState.error(_configurationUnavailable);
  }
}

class GovernmentIdDocumentTypesNotifier
    extends _KycConfigurationNotifier<GovernmentIdDocumentCatalogue> {
  @override
  Future<NotifierState<GovernmentIdDocumentCatalogue>> fetch(
    KycService service,
  ) => service.getGovernmentIdDocumentTypes();
}
