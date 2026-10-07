import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/snap_to_pay_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_ocr_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

  test('a camera photo is cropped to the frame band and shrunk', () {
    final photo = img.encodeJpg(img.Image(width: 3000, height: 4000));

    final upload = img.decodeImage(shrinkForSnap(photo))!;

    // 92% of the width scaled to 1000; 35% of the height kept in proportion.
    expect(upload.width, 1000);
    expect(upload.height, 507);

    // A gallery photo has no frame, so it is shrunk whole.
    final whole = img.decodeImage(shrinkForSnap(photo, cropToFrame: false))!;
    expect(whole.width, 1000);
    expect(whole.height, 1333);
  });

  test('a scan photo is sent without its metadata or location', () {
    final source = img.Image(width: 1200, height: 1600);
    source.exif.imageIfd['Model'] = 'Pixel 7 Pro';
    source.exif.gpsIfd['GPSLatitude'] = 6.5244;

    final upload = img.decodeJpg(shrinkForSnap(img.encodeJpg(source)))!;

    expect(upload.exif.isEmpty, isTrue);
  });

  testWidgets('a scanned number routes only after the bank is selected', (
    tester,
  ) async {
    final sends = <({String route, String number, String? bankCode})>[];
    const number = '0123456789';
    const access = CommercialBank(code: '058', name: 'Access Bank');

    Future<void> pumpResult(Key key) => tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Scaffold(
          body: ScannedAccountResult(
            key: key,
            number: number,
            banks: const [boctrustBank, access],
            loading: false,
            onSend: (route, number, bankCode) =>
                sends.add((route: route, number: number, bankCode: bankCode)),
            onScanAgain: () {},
          ),
        ),
      ),
    );

    await pumpResult(const ValueKey('external'));
    expect(find.text('Choose a bank'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Access Bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    expect(sends.single, (
      route: AppRoutes.sendOtherBank,
      number: number,
      bankCode: '058',
    ));

    await pumpResult(const ValueKey('boctrust'));
    await tester.tap(find.text('Choose a bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BOCTRUST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    expect(sends.last, (
      route: AppRoutes.sendBeneficiary,
      number: number,
      bankCode: null,
    ));
  });

  test('the scan bank list offers BOCTRUST once, ahead of fetched banks', () {
    const access = CommercialBank(code: '058', name: 'Access Bank');
    const listedBoctrust = CommercialBank(
      code: '090117',
      name: 'BOCTRUST Microfinance Bank',
    );
    const fetched = [access, listedBoctrust];

    expect(
      scanToPayBanks(canBoctrust: true, canInterbank: true, fetched: fetched),
      [boctrustBank, access],
    );
    expect(
      scanToPayBanks(canBoctrust: false, canInterbank: true, fetched: fetched),
      [access],
    );
  });

  group('scanned result states', () {
    Future<void> pumpResult(
      WidgetTester tester, {
      String? errorMessage,
      VoidCallback? onRetry,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Scaffold(
          body: ScannedAccountResult(
            number: '0123456789',
            banks: const [],
            loading: false,
            errorMessage: errorMessage,
            onRetry: onRetry,
            onSend: (_, _, _) {},
            onScanAgain: () {},
          ),
        ),
      ),
    );

    testWidgets('a failed bank load can be retried', (tester) async {
      var retries = 0;
      await pumpResult(
        tester,
        errorMessage: 'Unable to load banks.',
        onRetry: () => retries++,
      );

      expect(find.text('Banks unavailable'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    testWidgets('no sendable bank explains why Continue is off', (
      tester,
    ) async {
      await pumpResult(tester);

      expect(find.text(kNoScanBanks), findsOneWidget);
    });
  });
}
