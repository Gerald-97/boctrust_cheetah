import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/scan_text_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/core_flow_widgets.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/snap_number_button.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/snap_to_pay_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/scan_text_recognizer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transfers extends CoreTransferService {
  _Transfers() : super(null);
  final calls = <String>[];

  @override
  Future<NotifierState<NameEnquiryResult>> boctrustNameEnquiry(
    String accountNumber, {
    CancelToken? cancelToken,
  }) async {
    calls.add('BOCTRUST $accountNumber');
    return const NotifierState.done(NameEnquiryResult('ADA OBI'));
  }

  @override
  Future<NotifierState<NameEnquiryResult>> nameEnquiry({
    required String bankCode,
    required String accountNumber,
    CancelToken? cancelToken,
  }) async {
    calls.add('$bankCode $accountNumber');
    return const NotifierState.done(NameEnquiryResult('ADA OBI'));
  }
}

class _Recognizer implements ScanTextRecognizer {
  _Recognizer(this.read);

  final Future<List<RecognizedLine>> Function(String path) read;

  @override
  Future<List<RecognizedLine>> recognize(String imagePath) => read(imagePath);
}

const _box = ScanTextBox(left: 0, top: 0, width: 1, height: 0.1);
const _access = CommercialBank(code: '044', name: 'Access Bank');
const _gtb = CommercialBank(code: '058', name: 'GTBank');

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

  group('reviewing a scanned recipient', () {
    const number = '0123456789';
    late List<({String code, String number})> checks;
    late List<Completer<({String? name, String? error})>> replies;
    late List<({String route, String number, String? bankCode})> sends;

    setUp(() {
      checks = [];
      replies = [];
      sends = [];
    });

    Future<void> pumpReview(
      WidgetTester tester, {
      required List<String> numbers,
      required BankMatch match,
    }) {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      return tester.pumpWidget(
        MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: Scaffold(
            body: ScannedAccountResult(
              numbers: numbers,
              bankMatch: match,
              banks: const [boctrustBank, _access, _gtb],
              loading: false,
              onCheck: (bank, number) {
                checks.add((code: bank.code, number: number));
                replies.add(Completer());
                return replies.last.future;
              },
              onSend: (route, number, bankCode) =>
                  sends.add((route: route, number: number, bankCode: bankCode)),
              onScanAgain: () {},
            ),
          ),
        ),
      );
    }

    testWidgets('a unique match is checked only when asked, then routes', (
      tester,
    ) async {
      await pumpReview(
        tester,
        numbers: const [number],
        match: const BankMatch(BankMatchStatus.unique, [_access, _gtb]),
      );

      expect(find.text(number), findsOneWidget);
      expect(find.text('Access Bank'), findsOneWidget);
      expect(checks, isEmpty);
      await tester.tap(find.text('Check account'));
      await tester.pump();
      expect(checks, [(code: '044', number: number)]);

      replies.single.complete((name: 'ADA OBI', error: null));
      await tester.pump();
      expect(find.text('ADA OBI'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      expect(sends.single, (
        route: AppRoutes.sendOtherBank,
        number: number,
        bankCode: '044',
      ));
    });

    testWidgets('with no bank matched, nothing is checked until one is '
        'picked', (tester) async {
      await pumpReview(
        tester,
        numbers: const [number],
        match: const BankMatch(BankMatchStatus.none, []),
      );

      await tester.tap(find.text('Check account'));
      await tester.pump();
      expect(checks, isEmpty);

      await tester.tap(find.text('Choose a bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GTBank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check account'));
      await tester.pump();
      expect(checks, [(code: '058', number: number)]);
    });

    testWidgets('two numbers and an ambiguous bank wait for choices', (
      tester,
    ) async {
      await pumpReview(
        tester,
        numbers: const [number, '9876543210'],
        match: const BankMatch(BankMatchStatus.ambiguous, [_access, _gtb]),
      );

      expect(find.text('Choose a bank'), findsOneWidget);
      expect(find.text('Access Bank'), findsOneWidget);
      await tester.tap(find.text('GTBank'));
      await tester.pump();
      await tester.tap(find.text('Check account'));
      await tester.pump();
      expect(checks, isEmpty);

      await tester.tap(find.text('9876543210'));
      await tester.pump();
      await tester.tap(find.text('Check account'));
      await tester.pump();
      expect(checks, [(code: '058', number: '9876543210')]);
    });

    testWidgets('a reply for an edited number is ignored', (tester) async {
      await pumpReview(
        tester,
        numbers: const [number],
        match: const BankMatch(BankMatchStatus.unique, [_access]),
      );

      await tester.tap(find.text('Check account'));
      await tester.pump();
      await tester.enterText(find.text(number), '0123456780');
      replies.single.complete((name: 'ADA OBI', error: null));
      await tester.pump();

      expect(find.text('ADA OBI'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('a failed check shows why and can be retried', (tester) async {
      await pumpReview(
        tester,
        numbers: const [number],
        match: const BankMatch(BankMatchStatus.unique, [_access]),
      );

      await tester.tap(find.text('Check account'));
      await tester.pump();
      replies.single.complete((name: null, error: kAccountNotFound));
      await tester.pump();
      expect(find.text(kAccountNotFound), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(checks, hasLength(2));
    });
  });

  testWidgets('a scanned recipient is checked through its own enquiry', (
    tester,
  ) async {
    final transfers = _Transfers();
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coreTransferServiceProvider.overrideWithValue(transfers)],
        child: Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox();
          },
        ),
      ),
    );

    await checkScannedAccount(ref, boctrustBank, '0123456789');
    await checkScannedAccount(ref, _gtb, '9876543210');

    expect(transfers.calls, ['BOCTRUST 0123456789', '058 9876543210']);
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
            numbers: const ['0123456789'],
            bankMatch: const BankMatch(BankMatchStatus.none, []),
            banks: const [],
            loading: false,
            errorMessage: errorMessage,
            onRetry: onRetry,
            onCheck: (_, _) async => (name: null, error: null),
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
