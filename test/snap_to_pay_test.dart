import 'dart:io';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/scan_text_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/snap_number_button.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/snap_to_pay_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/scan_text_recognizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recognizer implements ScanTextRecognizer {
  _Recognizer(this.read);

  final Future<List<RecognizedLine>> Function(String path) read;

  @override
  Future<List<RecognizedLine>> recognize(String imagePath) => read(imagePath);
}

const _box = ScanTextBox(left: 0, top: 0, width: 1, height: 0.1);

void main() {
  group('reading a photo from the account field', () {
    late Directory dir;
    late File photo;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('snap_number');
      photo = File('${dir.path}/photo.jpg')..writeAsStringSync('x');
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('the photo is deleted once its number is read', () async {
      final candidates = await readScanFile(
        _Recognizer(
          (_) async => const [RecognizedLine('Acct 0123456789', _box)],
        ),
        photo.path,
      );

      expect(candidates.accountNumbers, ['0123456789']);
      expect(photo.existsSync(), isFalse);
    });

    test('the photo is deleted when recognition fails', () async {
      await expectLater(
        readScanFile(
          _Recognizer((_) => throw const ScanRecognitionFailure('failed')),
          photo.path,
        ),
        throwsA(isA<ScanRecognitionFailure>()),
      );

      expect(photo.existsSync(), isFalse);
    });
  });

  testWidgets('with two numbers read, the tapped one is chosen', (
    tester,
  ) async {
    String? chosen;
    await tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => chosen = await chooseScannedNumber(
              context,
              const ['0123456789', '9876543210'],
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('0123456789'), findsOneWidget);
    await tester.tap(find.text('9876543210'));
    await tester.pumpAndSettle();

    expect(chosen, '9876543210');
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
