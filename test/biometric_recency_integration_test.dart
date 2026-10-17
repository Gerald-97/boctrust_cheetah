import 'dart:async';

import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_flow_models.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/biometric_login_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/login_flow_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_storage.dart';

const _profile = RememberedBiometricProfile(
  userId: 'user-1',
  identifier: '+2348031234567',
  identifierType: IdentifierType.phoneNumber,
  firstName: 'Ada',
  biometricType: BiometricPresentation.fingerprint,
);

class _PendingPromptGateway implements BiometricAuthGateway {
  final prompt = Completer<BiometricAuthOutcome>();

  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) =>
      prompt.future;

  @override
  Future<void> stopAuthentication() async {}
}

final _submitted = <String>[];

class _RecordingLoginFlow extends LoginFlowNotifier {
  @override
  Future<LoginAttemptResult> login(String rawIdentifier, String password) {
    _submitted.add(rawIdentifier);
    return Future.value(
      LoginAttemptResult(
        outcome: LoginAttemptOutcome.completed,
        identifier: rawIdentifier,
      ),
    );
  }
}

void main() {
  test(
    'a prompt that finishes after recency invalidation cannot sign in',
    () async {
      _submitted.clear();
      final memory = MemorySecureStorage();
      final secure = SecureStorage(storage: memory);
      final biometrics = BiometricLoginStorage(secure);
      final recency = AppOpenRecency(
        secure,
        biometrics,
        BiometricTransferStorage(secure),
      );
      final gateway = _PendingPromptGateway();
      await biometrics.enable(
        profile: _profile,
        identifier: _profile.identifier,
        password: 'Secret#123',
      );
      memory.values[secure.lastOpenKey] = DateTime.utc(
        2026,
        4,
        1,
      ).toIso8601String();
      await recency.recordOpen(DateTime.utc(2026, 4, 2));

      final container = ProviderContainer(
        overrides: [
          biometricAuthGatewayProvider.overrideWithValue(gateway),
          biometricLoginStorageProvider.overrideWithValue(biometrics),
          appOpenRecencyProvider.overrideWithValue(recency),
          loginFlowProvider.overrideWith(_RecordingLoginFlow.new),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(biometricLoginProvider.notifier);
      await notifier.hydrate();
      expect(container.read(biometricLoginProvider).isEnabled, isTrue);

      final login = notifier.loginWithBiometrics();
      await pumpEventQueue();
      // A stale open whose cleanup fails leaves the credential on disk.
      memory.failDeletes.addAll(
        BiometricStorageKey.values.map(secure.biometricKey),
      );
      await recency.recordOpen(DateTime.utc(2026, 11, 2));
      gateway.prompt.complete(BiometricAuthOutcome.success);

      expect((await login).succeeded, isFalse);
      expect(_submitted, isEmpty);
      expect(container.read(authSessionProvider), isNull);
      expect(container.read(biometricLoginProvider).isEnabled, isFalse);
    },
  );

  test(
    'recency clears both enrollments, and a failed transfer cleanup blocks both features',
    () async {
      final memory = MemorySecureStorage();
      final secure = SecureStorage(storage: memory);
      final logins = BiometricLoginStorage(secure);
      final transfers = BiometricTransferStorage(secure);
      final recency = AppOpenRecency(secure, logins, transfers);
      Future<void> enrollBoth() async {
        await logins.enable(
          profile: _profile,
          identifier: _profile.identifier,
          password: 'Secret#123',
        );
        await transfers.enable(userId: _profile.userId, pin: '0007');
      }

      await enrollBoth();
      memory.values[secure.lastOpenKey] = DateTime.utc(
        2026,
        1,
        1,
      ).toIso8601String();
      expect(
        await recency.recordOpen(DateTime.utc(2026, 8, 1)),
        AppOpenRecencyResult.passwordRequired,
      );
      expect(await logins.loadValidEnrollment(), isNull);
      expect(await transfers.loadValidEnrollment(), isNull);
      expect(recency.biometricsBlocked, isFalse);

      // Login was never on, so there is no login message to show.
      await transfers.enable(userId: _profile.userId, pin: '0007');
      expect(
        await recency.recordOpen(DateTime.utc(2027, 3, 1)),
        AppOpenRecencyResult.eligible,
      );
      expect(await transfers.loadValidEnrollment(), isNull);

      await enrollBoth();
      memory.failDeletes.add(
        secure.biometricTransferKey(BiometricTransferStorageKey.pin),
      );
      expect(
        await recency.recordOpen(DateTime.utc(2027, 10, 1)),
        AppOpenRecencyResult.passwordRequired,
      );
      expect(recency.biometricsBlocked, isTrue);
      // The stale time stays, so the next open retries the cleanup.
      expect(memory.values[secure.lastOpenKey], startsWith('2027-03-01'));
    },
  );
}
