import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/api_endpoints.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.data);
  final Object? data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'OK',
        'data': data,
        'meta': {'requestId': 'req-1'},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _operation(String provider) => {
  'provider': provider,
  'product': 'government_id_verification',
  'sdkJobType': 'dojahGovernmentId',
  'jobType': 'government_id',
  'callbackUrl': null,
};

final _providerConfig = {
  'activeProvider': 'dojah',
  'environment': 'sandbox',
  'identity': _operation('dojah'),
  'governmentId': _operation('dojah'),
};

final _catalogue = {
  'documentTypes': [
    {
      'value': 'national_id',
      'label': 'National ID',
      'description': 'Your NIN.',
      'requiresDocumentNumber': false,
      'active': true,
    },
  ],
};

({KycService service, _RecordingAdapter adapter}) _service(Object? data) {
  final adapter = _RecordingAdapter(data);
  final dio = Dio(BaseOptions(baseUrl: 'https://user.example.test/api/v1'))
    ..httpClientAdapter = adapter;
  return (service: KycService(ApiService(dio)), adapter: adapter);
}

void main() {
  test('provider config is one authenticated GET to its exact path', () async {
    final harness = _service(_providerConfig);

    final state = await harness.service.getProviderConfig();

    expect(state.status, ServiceStatus.success);
    expect(state.data?.governmentId.provider, KycProvider.dojah);
    expect(harness.adapter.requests, hasLength(1));
    expect(harness.adapter.requests.single.method, 'GET');
    expect(
      harness.adapter.requests.single.uri.path,
      '/api/v1/users/me/kyc/provider-config',
    );
  });

  test(
    'document catalogue is one authenticated GET to its exact path',
    () async {
      final harness = _service(_catalogue);

      final state = await harness.service.getGovernmentIdDocumentTypes();

      expect(state.status, ServiceStatus.success);
      expect(state.data?.types, [GovernmentIdDocumentType.nationalId]);
      expect(harness.adapter.requests, hasLength(1));
      expect(harness.adapter.requests.single.method, 'GET');
      expect(
        harness.adapter.requests.single.uri.path,
        '/api/v1/users/me/kyc/government-id/document-types',
      );
    },
  );

  test('a malformed or empty catalogue is an error, not a throw', () async {
    for (final data in <Object?>[
      {'documentTypes': []},
      {'documentTypes': 'nope'},
      null,
    ]) {
      final state = await _service(data).service.getGovernmentIdDocumentTypes();
      expect(state.status, ServiceStatus.error, reason: '$data');
      expect(state.data, isNull);
    }
  });

  test('an unknown environment is an error, not a throw', () async {
    final state = await _service({
      ..._providerConfig,
      'environment': 'production',
    }).service.getProviderConfig();
    expect(state.status, ServiceStatus.error);
  });

  test('neither operation is public', () {
    expect(ApiEndpoints.kycProviderConfig, '/users/me/kyc/provider-config');
    expect(
      ApiEndpoints.governmentIdDocumentTypes,
      '/users/me/kyc/government-id/document-types',
    );
    expect(ApiEndpoints.isPublic('GET', ApiEndpoints.kycProviderConfig), false);
    expect(
      ApiEndpoints.isPublic('GET', ApiEndpoints.governmentIdDocumentTypes),
      false,
    );
  });
}
