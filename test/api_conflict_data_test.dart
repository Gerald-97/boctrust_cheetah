import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.statusCode, this.body);
  final int statusCode;
  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

ApiService _api(int statusCode, Map<String, Object?> body) =>
    ApiService(Dio()..httpClientAdapter = _Adapter(statusCode, body));

void main() {
  test('a 409 keeps the existing resource the backend returns', () async {
    final response = await _api(409, {
      'success': false,
      'message': 'Verification already in progress.',
      'code': 'VERIFICATION_IN_PROGRESS',
      'data': {'id': 'existing'},
    }).postData<String>('/x', parser: (json) => (json! as Map)['id'] as String);

    expect(response.statusCode, 409);
    expect(response.errorCode, 'VERIFICATION_IN_PROGRESS');
    expect(response.data, 'existing');
  });

  test(
    'a 409 with unparseable data is still reported as the conflict',
    () async {
      final response =
          await _api(409, {
            'success': false,
            'message': 'Verification already in progress.',
            'code': 'VERIFICATION_IN_PROGRESS',
            'data': 'not a map',
          }).postData<String>(
            '/x',
            parser: (json) => (json! as Map)['id'] as String,
          );

      expect(response.message, 'Verification already in progress.');
      expect(response.errorCode, 'VERIFICATION_IN_PROGRESS');
      expect(response.data, isNull);
    },
  );

  test('other error statuses do not expose data', () async {
    final response = await _api(400, {
      'success': false,
      'message': 'Bad request.',
      'data': {'id': 'ignored'},
    }).postData<String>('/x', parser: (json) => (json! as Map)['id'] as String);

    expect(response.data, isNull);
  });
}
