import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_ocr_service.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';

class _Core implements HttpClientAdapter {
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
        'message': 'ok',
        'data': {'number': '0123456789'},
        'meta': {},
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

void main() {
  late _Core core;
  late CoreOcrService service;

  setUp(() {
    core = _Core();
    service = CoreOcrService(
      ApiService(
        Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
          ..httpClientAdapter = core,
      ),
    );
  });

  test('snap sends bare base64 and returns the number', () async {
    final image = Uint8List.fromList([1, 2, 3]);
    final result = await service.readNumber(image);

    expect(result.data, '0123456789');
    expect(core.requests.single.path, '/me/snap-to-pay');
    expect(core.requests.single.data, {'image': base64Encode(image)});
  });

  test('an oversized photo is refused before upload', () async {
    final result = await service.readNumber(Uint8List(kSnapImageMaxBytes + 1));

    expect(result.isError, isTrue);
    expect(core.requests, isEmpty);
  });

  test('a camera photo is shrunk for upload', () {
    final photo = img.encodeJpg(img.Image(width: 3000, height: 2000));

    final upload = img.decodeImage(shrinkForSnap(photo))!;

    expect(upload.width, 1280);
    expect(upload.height, 853);
  });
}
