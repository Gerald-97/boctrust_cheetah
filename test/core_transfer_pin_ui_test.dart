import 'dart:async';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/interbank_transfer_screen.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/core_flow_widgets.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/beneficiary_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_beneficiary_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/biometric_overrides.dart';
import 'support/flow_harness.dart';
import 'support/memory_secure_storage.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CustomerBankAccountsNotifier {
  @override
  NotifierState<CustomerBankAccountsData> build() => NotifierState.done(
    CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [
        {
          'productCode': 'bocFlex',
          'productName': 'Boc Flex',
          'accountNumber': '0000000001',
          'status': 'active',
          'availableBalance': '5000.00',
          'ledgerBalance': '5000.00',
        },
      ],
    }),
  );

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));
  final lookups = <String>[];
  NotifierState<NameEnquiryResult> lookupResult = const NotifierState.done(
    NameEnquiryResult('ADA OBI'),
  );

  /// When set, lookups wait on it instead of answering at once.
  Completer<NotifierState<NameEnquiryResult>>? pending;

  NotifierState<CoreTransferInitiation> initiation = NotifierState.done(
    CoreTransferInitiation(
      reference: 'a1b2c3d4e5f6',
      checks: const {CoreTransferCheck.pin},
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    ),
  );
  final pins = <String>[];
  final otps = <String>[];
  var resends = 0;
  var finalized = 0;
  var requeries = 0;
  CoreLiveState requeryState = CoreLiveState.pending;

  /// When set, initiate waits on it instead of answering at once.
  Completer<void>? initiateGate;

  /// When set, PIN verification waits on it instead of answering at once.
  Completer<void>? pinGate;

  /// When set, PIN verification answers with it.
  NotifierState<CoreCheckProgress>? pinReply;

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateBoctrust(
    BoctrustTransferDraft draft,
  ) async {
    await initiateGate?.future;
    return initiation;
  }

  CoreCheckProgress _after(CoreTransferInitiation initiation) =>
      CoreCheckProgress(
        reference: initiation.reference,
        otpSent: initiation.needsOtp,
      );

  @override
  Future<NotifierState<CoreCheckProgress>> verifyTransferPin(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String pin,
  ) async {
    pins.add(pin);
    await pinGate?.future;
    if (pinReply case final reply?) return reply;
    return NotifierState.done(
      initiation.needsOtp
          ? CoreCheckProgress(
              reference: initiation.reference,
              pending: const {CoreTransferCheck.otp},
              otpSent: true,
            )
          : _after(initiation),
    );
  }

  @override
  Future<NotifierState<CoreCheckProgress>> resendTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    resends++;
    return NotifierState.done(_after(initiation));
  }

  /// When set, OTP verify waits on it instead of answering at once.
  Completer<void>? otpGate;

  @override
  Future<NotifierState<CoreCheckProgress>> verifyTransferOtp(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String otp,
  ) async {
    otps.add(otp);
    await otpGate?.future;
    return otp == '000000'
        ? const NotifierState.error('Incorrect.', statusCode: 401)
        : NotifierState.done(
            CoreCheckProgress(reference: initiation.reference),
          );
  }

  @override
  Future<ServiceResponse<CoreTransferAck>> finalizeTransfer(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
  ) async {
    finalized++;
    return const ServiceResponse.success(
      CoreTransferAck(responseCode: '00', retrievalReference: 'a1b2c3d4e5f6'),
      statusCode: 200,
    );
  }

  @override
  Future<NotifierState<CoreLiveTransferStatus>> requeryTransfer(
    CoreTrackingReference tracking,
  ) async {
    requeries++;
    return NotifierState.done(
      CoreLiveTransferStatus(state: requeryState, trackingReference: tracking),
    );
  }

  @override
  Future<NotifierState<NameEnquiryResult>> nameEnquiry({
    required String bankCode,
    required String accountNumber,
    CancelToken? cancelToken,
  }) async {
    lookups.add('$bankCode $accountNumber');
    return pending?.future ?? lookupResult;
  }

  @override
  Future<NotifierState<List<CommercialBank>>> getBanks() async =>
      const NotifierState.done([
        CommercialBank(code: '044', name: 'Access Bank'),
        CommercialBank(code: '090117', name: 'Boctrust MFB'),
        CommercialBank(code: '058', name: 'GTBank'),
      ]);
}

/// One saved account at Access and one at Boctrust.
class _Saved extends CoreBeneficiaryService {
  const _Saved() : super(null);

  @override
  Future<NotifierState<List<Beneficiary>>> list() async =>
      const NotifierState.done([
        Beneficiary(
          id: 'a',
          type: BeneficiaryType.bankAccount,
          number: '0123456789',
          name: 'SAVED ACCESS',
          bankCode: '044',
          bankName: 'Access Bank',
        ),
        Beneficiary(
          id: 'b',
          type: BeneficiaryType.bankAccount,
          number: '1100037777',
          name: 'SAVED BOC',
          bankCode: '090117',
          bankName: 'Boctrust MFB',
        ),
      ]);
}

/// Lets the PIN field's blinking cursor run without `pumpAndSettle`.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pumpBoctrust(
  WidgetTester tester,
  _Transfers transfers, {
  String? initialAccountNumber,
  List<dynamic>? biometrics,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...await flowTestOverrides(),
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreTransferServiceProvider.overrideWithValue(transfers),
        transferAuthorizationReadyProvider.overrideWithValue(true),
        ...biometrics ?? biometricTestOverrides(),
      ],
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: InterbankTransferFlow.boctrust(
          onExit: () {},
          onSectionSelected: (_) {},
          initialAccountNumber: initialAccountNumber,
        ),
      ),
    ),
  );
  await _settle(tester);
}

/// A complete number is looked up as soon as it is typed.
Future<void> _checkAccount(WidgetTester tester, String number) async {
  await tester.enterText(find.byType(EditableText).first, number);
  await _settle(tester);
}

/// Resolves the recipient, enters ₦10 and opens the PIN sheet.
Future<void> _sendTen(WidgetTester tester) async {
  await _checkAccount(tester, '1100037777');
  await tester.tap(find.text('Continue'));
  await _settle(tester);
  await tester.enterText(find.byType(EditableText).first, '10');
  await tester.pump();
  await tester.tap(find.text('Review'));
  await _settle(tester);
  await tester.tap(find.textContaining('Send ₦'));
  await _settle(tester);
}

Future<void> _enterCode(WidgetTester tester, String code, String button) async {
  await tester.enterText(find.byType(EditableText).last, code);
  await tester.pump();
  await tester.tap(find.text(button));
  await _settle(tester);
}

class _Fingerprint implements BiometricAuthGateway {
  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) async =>
      BiometricAuthOutcome.success;

  @override
  Future<void> stopAuthentication() async {}
}

/// A device enrolled for biometric approval with the saved PIN '0007'.
Future<(BiometricTransferStorage, List<dynamic>)> _enrolled() async {
  final secure = SecureStorage(storage: MemorySecureStorage());
  final login = BiometricLoginStorage(secure);
  final storage = BiometricTransferStorage(secure);
  final recency = AppOpenRecency(secure, login, storage);
  // A first open clears any enrollment, so enroll after it.
  await recency.recordColdLaunch();
  await storage.enable(userId: savingsSession().userId, pin: '0007');
  return (
    storage,
    <dynamic>[
      biometricAuthGatewayProvider.overrideWithValue(_Fingerprint()),
      biometricLoginStorageProvider.overrideWithValue(login),
      biometricTransferStorageProvider.overrideWithValue(storage),
      appOpenRecencyProvider.overrideWithValue(recency),
    ],
  );
}

void main() {
  group('BOCTRUST recipient lookup', () {
    testWidgets('account entry keeps only the first ten pasted digits', (
      tester,
    ) async {
      final transfers = _Transfers();
      await _pumpBoctrust(tester, transfers);

      await tester.enterText(
        find.byType(EditableText).first,
        '11000abc3777799',
      );
      await _settle(tester);

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        '1100037777',
      );
      expect(transfers.lookups, ['090117 1100037777']);
    });

    testWidgets('a reply for an earlier number is discarded', (tester) async {
      final transfers = _Transfers()..pending = Completer();
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '1100037777');
      await tester.enterText(find.byType(EditableText).first, '110003888');
      await tester.pump();
      transfers.pending!.complete(
        const NotifierState.done(NameEnquiryResult('ADA OBI')),
      );
      await _settle(tester);

      expect(find.text('ADA OBI'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('changing a digit clears the resolved name', (tester) async {
      await _pumpBoctrust(tester, _Transfers());

      await _checkAccount(tester, '1100037777');
      expect(find.text('ADA OBI'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '110003777');
      await tester.pump();

      expect(find.text('ADA OBI'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('an unknown account says so', (tester) async {
      final transfers = _Transfers()
        ..lookupResult = const NotifierState.error(
          'Not found',
          statusCode: 404,
        );
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '1100037777');

      expect(find.text(kAccountNotFound), findsOneWidget);
    });

    testWidgets('only a complete number is looked up, once', (tester) async {
      final transfers = _Transfers()..pending = Completer();
      await _pumpBoctrust(tester, transfers);

      await _checkAccount(tester, '110003777');
      expect(transfers.lookups, isEmpty);
      await _checkAccount(tester, '1100037777');
      await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
      await _settle(tester);

      expect(transfers.lookups, ['090117 1100037777']);
    });

    testWidgets('a scanned number is looked up before review', (tester) async {
      final transfers = _Transfers();
      await _pumpBoctrust(
        tester,
        transfers,
        initialAccountNumber: '1100037777',
      );

      expect(transfers.lookups, ['090117 1100037777']);
      expect(find.text('ADA OBI'), findsOneWidget);
      expect(find.text('Review'), findsNothing);
    });
  });

  group('staged BOCTRUST transfer', () {
    testWidgets('automatically checks a pending transfer once', (tester) async {
      final transfers = _Transfers()..requeryState = CoreLiveState.completed;
      await _pumpBoctrust(tester, transfers);
      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Confirm transfer');

      expect(find.text('Transfer processing'), findsOneWidget);
      expect(transfers.requeries, 0);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(transfers.requeries, 1);
      expect(find.text('Transfer successful'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(transfers.requeries, 1);
    });

    testWidgets('manual status check cancels the automatic check', (
      tester,
    ) async {
      final transfers = _Transfers();
      await _pumpBoctrust(tester, transfers);
      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Confirm transfer');

      await tester.tap(find.text('Check status'));
      await tester.pump();
      expect(transfers.requeries, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(transfers.requeries, 1);
    });

    testWidgets('leaving the result cancels the automatic check', (
      tester,
    ) async {
      final transfers = _Transfers();
      await _pumpBoctrust(tester, transfers);
      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Confirm transfer');
      expect(transfers.requeries, 0);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
      expect(transfers.requeries, 0);
    });

    testWidgets('a covered result does not check in the background', (
      tester,
    ) async {
      final transfers = _Transfers();
      await _pumpBoctrust(tester, transfers);
      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Confirm transfer');
      expect(transfers.requeries, 0);

      final context = tester.element(find.byType(InterbankTransferFlow));
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold()));
      await tester.pump(const Duration(seconds: 2));
      expect(transfers.requeries, 0);
    });

    testWidgets(
      'shows progress while the PIN verification request is pending',
      (tester) async {
        final transfers = _Transfers()..pinGate = Completer<void>();
        await _pumpBoctrust(tester, transfers);

        await _sendTen(tester);
        await tester.enterText(find.byType(EditableText).last, '0007');
        await tester.pump();
        await tester.tap(find.text('Confirm transfer'));
        await _settle(tester);

        expect(transfers.pins, ['0007']);
        expect(find.text('Verifying your PIN'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(transfers.finalized, 0);

        transfers.pinGate!.complete();
        await _settle(tester);
        expect(transfers.finalized, 1);
        expect(find.text('Transfer processing'), findsOneWidget);
      },
    );

    testWidgets('PIN only: finalized once with the PIN', (tester) async {
      final transfers = _Transfers();
      await _pumpBoctrust(tester, transfers);

      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Confirm transfer');

      expect(transfers.pins, ['0007']);
      expect(transfers.otps, isEmpty);
      expect(find.byKey(const Key('transfer-otp-sheet')), findsNothing);
      expect(transfers.finalized, 1);
      expect(find.text('Transfer processing'), findsOneWidget);
    });

    testWidgets('PIN, then OTP: finalized only after the code is verified', (
      tester,
    ) async {
      final transfers = _Transfers()
        ..initiation = NotifierState.done(
          CoreTransferInitiation(
            reference: 'a1b2c3d4e5f6',
            checks: const {CoreTransferCheck.pin, CoreTransferCheck.otp},
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        );
      await _pumpBoctrust(tester, transfers);

      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Verify PIN');
      // Core sent the code when the PIN passed; the sheet does not request
      // one on open.
      expect(find.byKey(const Key('transfer-otp-sheet')), findsOneWidget);
      expect(transfers.finalized, 0);

      await _enterCode(tester, '000000', 'Verify code');
      expect(find.text('That code is incorrect or has expired.'), findsOne);
      expect(transfers.finalized, 0);

      await tester.tap(find.text('Resend code'));
      await _settle(tester);
      expect(transfers.resends, 1);

      await _enterCode(tester, '123456', 'Verify code');
      expect(transfers.otps, ['000000', '123456']);
      expect(transfers.finalized, 1);
      expect(find.byKey(const Key('transfer-otp-sheet')), findsNothing);
    });

    testWidgets('closing the OTP sheet mid-verify releases the transfer', (
      tester,
    ) async {
      final transfers = _Transfers()
        ..otpGate = Completer()
        ..initiation = NotifierState.done(
          CoreTransferInitiation(
            reference: 'a1b2c3d4e5f6',
            checks: const {CoreTransferCheck.pin, CoreTransferCheck.otp},
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        );
      await _pumpBoctrust(tester, transfers);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InterbankTransferFlow)),
      );

      await _sendTen(tester);
      await _enterCode(tester, '0007', 'Verify PIN');
      await _enterCode(tester, '123456', 'Verify code');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      transfers.otpGate!.complete();
      await _settle(tester);

      expect(container.read(coreTransferAttemptProvider).current, isNull);
      expect(transfers.finalized, 0);
    });

    testWidgets('leaving while it starts releases the transfer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transfers = _Transfers()..initiateGate = Completer();
      var open = true;
      late StateSetter setOpen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await flowTestOverrides(),
            authSessionProvider.overrideWith(SavingsSession.new),
            customerBankAccountsProvider.overrideWith(_Accounts.new),
            coreTransferServiceProvider.overrideWithValue(transfers),
            transferAuthorizationReadyProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: CheetahTheme.lightTheme,
            home: StatefulBuilder(
              builder: (context, setState) {
                setOpen = setState;
                return open
                    ? InterbankTransferFlow.boctrust(
                        onExit: () {},
                        onSectionSelected: (_) {},
                      )
                    : const SizedBox();
              },
            ),
          ),
        ),
      );
      await _settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      await _sendTen(tester);
      setOpen(() => open = false);
      await _settle(tester);
      transfers.initiateGate!.complete();
      await _settle(tester);

      expect(container.read(coreTransferAttemptProvider).current, isNull);
    });

    testWidgets('a liveness check is refused without finalizing', (
      tester,
    ) async {
      final transfers = _Transfers()
        ..initiation = NotifierState.done(
          CoreTransferInitiation(
            reference: 'a1b2c3d4e5f6',
            checks: const {CoreTransferCheck.pin, CoreTransferCheck.liveness},
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          ),
        );
      await _pumpBoctrust(tester, transfers);

      await _sendTen(tester);

      expect(find.byKey(const Key('transaction-pin-sheet')), findsNothing);
      expect(find.text('Transfer declined'), findsOneWidget);
      expect(transfers.finalized, 0);
    });
  });

  // BOCTRUST recipients are paid through the intrabank flow, so the
  // other-bank screen never preselects Boctrust from a link or beneficiary.
  testWidgets('another bank never preselects BOCTRUST', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transfers = _Transfers();
    await pumpFlow(
      tester,
      route: AppRoutes.sendOtherBank,
      arguments: const AppRouteArguments(
        entityId: '1100037777',
        bankCode: '090117',
      ),
      overrides: [
        featureAvailabilityProvider(
          FeatureCapability.interbankTransfers,
        ).overrideWithValue(FeatureAvailability.available),
        featureAvailabilityProvider(
          FeatureCapability.beneficiaries,
        ).overrideWithValue(FeatureAvailability.available),
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreTransferServiceProvider.overrideWithValue(transfers),
        coreBeneficiaryServiceProvider.overrideWithValue(const _Saved()),
      ],
    );
    await _settle(tester);

    expect(transfers.lookups, isEmpty);
    expect(find.text('SAVED ACCESS'), findsOneWidget);
    expect(find.text('SAVED BOC'), findsNothing);
  });

  testWidgets('a scanned bank code preselects that bank for another bank', (
    tester,
  ) async {
    final transfers = _Transfers();
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpFlow(
      tester,
      route: AppRoutes.sendOtherBank,
      arguments: const AppRouteArguments(
        entityId: '0123456789',
        bankCode: '058',
      ),
      overrides: [
        featureAvailabilityProvider(
          FeatureCapability.interbankTransfers,
        ).overrideWithValue(FeatureAvailability.available),
        authSessionProvider.overrideWith(SavingsSession.new),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
        coreTransferServiceProvider.overrideWithValue(transfers),
      ],
    );
    await _settle(tester);

    expect(find.text('GTBank'), findsOneWidget);
    expect(find.text('0123456789'), findsOneWidget);
    expect(transfers.lookups, ['058 0123456789']);
    expect(find.text('ADA OBI'), findsOneWidget);
  });

  testWidgets('a failed BOCTRUST lookup cannot unlock the amount step', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transfers = _Transfers()
      ..lookupResult = const NotifierState.error(
        'Account lookup failed. Try again.',
        data: NameEnquiryResult('ADA OBI'),
        statusCode: 409,
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          authSessionProvider.overrideWith(SavingsSession.new),
          customerBankAccountsProvider.overrideWith(_Accounts.new),
          coreTransferServiceProvider.overrideWithValue(transfers),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: InterbankTransferFlow.boctrust(
            onExit: () {},
            onSectionSelected: (_) {},
          ),
        ),
      ),
    );
    await _settle(tester);

    await tester.enterText(find.byType(EditableText).first, '1100037777');
    await _settle(tester);

    expect(find.text('ADA OBI'), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('Account lookup failed. Try again.'), findsOneWidget);
    expect(find.text('Check account'), findsOneWidget);
  });

  testWidgets('biometric approval of a staged BOCTRUST transfer', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    // Approves with one PIN verification.
    var transfers = _Transfers();
    var (storage, biometrics) = await _enrolled();
    await _pumpBoctrust(tester, transfers, biometrics: biometrics);
    await _sendTen(tester);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsNothing);
    await tester.tap(find.text('Use fingerprint'));
    await _settle(tester);
    expect(transfers.pins, ['0007']);
    expect(transfers.finalized, 1);

    // "Use PIN instead" opens the PIN sheet.
    transfers = _Transfers();
    (storage, biometrics) = await _enrolled();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpBoctrust(tester, transfers, biometrics: biometrics);
    await _sendTen(tester);
    await tester.tap(find.text('Use PIN instead'));
    await _settle(tester);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsOneWidget);
    expect(transfers.pins, isEmpty);

    // A rejected saved PIN opens the PIN sheet with approval turned off.
    transfers = _Transfers()
      ..pinReply = const NotifierState.error('Incorrect.', statusCode: 401);
    (storage, biometrics) = await _enrolled();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpBoctrust(tester, transfers, biometrics: biometrics);
    await _sendTen(tester);
    await tester.tap(find.text('Use fingerprint'));
    await _settle(tester);
    expect(transfers.pins, ['0007']);
    expect(find.byKey(const Key('transaction-pin-sheet')), findsOneWidget);
    expect(
      find.text(
        'Biometric approval has been turned off. Enter your transaction PIN.',
      ),
      findsOneWidget,
    );
    expect(await storage.loadValidEnrollment(), isNull);
  });
}
