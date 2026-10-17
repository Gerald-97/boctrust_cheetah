import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_check_progress.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/biometric_transfer_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_storage.dart';
import 'support/savings_fixtures.dart';

class _Gateway implements BiometricAuthGateway {
  BiometricAuthOutcome outcome = BiometricAuthOutcome.success;
  void Function()? onPrompt;

  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) async {
    onPrompt?.call();
    return outcome;
  }

  @override
  Future<void> stopAuthentication() async {}
}

/// Initiates a PIN-only transfer and records every PIN verification.
class _Transfers extends CoreTransferService {
  _Transfers() : super(null);

  final pins = <String>[];
  NotifierState<CoreCheckProgress>? pinReply;

  @override
  Future<NotifierState<CoreTransferInitiation>> initiateBoctrust(
    BoctrustTransferDraft draft,
  ) async => NotifierState.done(
    CoreTransferInitiation(
      reference: 'a1b2c3d4e5f6',
      checks: {CoreTransferCheck.pin},
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
    ),
  );

  @override
  Future<NotifierState<CoreCheckProgress>> verifyTransferPin(
    CoreTransferKind kind,
    CoreTransferInitiation initiation,
    String pin,
  ) async {
    pins.add(pin);
    return pinReply ??
        const NotifierState.done(
          CoreCheckProgress(reference: 'a1b2c3d4e5f6', pending: {}),
        );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized().handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );

  late _Gateway gateway;
  late _Transfers transfers;
  late BiometricTransferStorage storage;
  late ProviderContainer container;

  setUp(() async {
    gateway = _Gateway();
    transfers = _Transfers();
    final secure = SecureStorage(storage: MemorySecureStorage());
    storage = BiometricTransferStorage(secure);
    final recency = AppOpenRecency(
      secure,
      BiometricLoginStorage(secure),
      storage,
    );
    // A first open clears any enrollment, so enroll after it.
    await recency.recordColdLaunch();
    await storage.enable(userId: savingsSession().userId, pin: '0007');
    container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        transferAuthorizationReadyProvider.overrideWithValue(true),
        coreTransferServiceProvider.overrideWithValue(transfers),
        biometricAuthGatewayProvider.overrideWithValue(gateway),
        biometricTransferStorageProvider.overrideWithValue(storage),
        appOpenRecencyProvider.overrideWithValue(recency),
      ],
    );
    addTearDown(container.dispose);
    await container.read(biometricApprovalProvider.notifier).hydrate();
  });

  Future<int> initiate() async {
    final notifier = container.read(coreTransferAttemptProvider.notifier);
    final id = notifier.beginReview(
      const BoctrustTransferDraft(
        toAccountNumber: '1100037777',
        amountKobo: '1000',
      ),
    )!;
    await notifier.initiate(id);
    return id;
  }

  Future<ApprovalResult> approve(int id) =>
      container.read(biometricApprovalProvider.notifier).approve(id);

  test('approve sends one PIN verification with the saved PIN', () async {
    expect(container.read(biometricApprovalProvider).enabled, isTrue);
    // The OS prompt leaves the app inactive; that still counts as active.
    final binding = TestWidgetsFlutterBinding.instance;
    gateway.onPrompt = () =>
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    addTearDown(
      () => binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );

    expect(await approve(await initiate()), ApprovalResult.passed);

    expect(transfers.pins, ['0007']);
    expect(
      container.read(coreTransferAttemptProvider).current?.phase,
      CoreTransferPhase.readyToFinalize,
    );
  });

  test('a cancelled prompt sends nothing', () async {
    gateway.outcome = BiometricAuthOutcome.cancelled;

    expect(await approve(await initiate()), ApprovalResult.cancelled);

    expect(transfers.pins, isEmpty);
    expect(await storage.loadValidEnrollment(), savingsSession().userId);
  });

  test('a rejected PIN wipes the enrollment', () async {
    transfers.pinReply = const NotifierState.error('x', statusCode: 401);

    expect(await approve(await initiate()), ApprovalResult.wiped);

    expect(transfers.pins, ['0007']);
    expect(await storage.loadValidEnrollment(), isNull);
    expect(container.read(biometricApprovalProvider).enabled, isFalse);
  });
}
