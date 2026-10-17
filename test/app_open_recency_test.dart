import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_storage.dart';

const _profile = RememberedBiometricProfile(
  userId: 'user-1',
  identifier: '+2348031234567',
  identifierType: IdentifierType.phoneNumber,
  firstName: 'Ada',
  biometricType: BiometricPresentation.fingerprint,
);

void main() {
  late MemorySecureStorage memory;
  late SecureStorage secure;
  late BiometricLoginStorage biometrics;
  late AppOpenRecency recency;

  setUp(() async {
    memory = MemorySecureStorage();
    secure = SecureStorage(storage: memory);
    biometrics = BiometricLoginStorage(secure);
    recency = AppOpenRecency(
      secure,
      biometrics,
      BiometricTransferStorage(secure),
    );
    await biometrics.enable(
      profile: _profile,
      identifier: _profile.identifier,
      password: 'Secret#123',
    );
  });

  void seedLastOpen(DateTime value) =>
      memory.values[secure.lastOpenKey] = value.toIso8601String();

  test(
    'exactly six calendar months stays eligible; one instant beyond clears',
    () async {
      // August 31 has no February anniversary: it clamps to February 28.
      final lastOpen = DateTime.utc(2026, 8, 31, 10);
      final anniversary = DateTime.utc(2027, 2, 28, 10);

      seedLastOpen(lastOpen);
      expect(
        await recency.recordOpen(anniversary),
        AppOpenRecencyResult.eligible,
      );
      expect(await biometrics.loadValidEnrollment(), isNotNull);

      seedLastOpen(lastOpen);
      final beyond = anniversary.add(const Duration(microseconds: 1));
      expect(
        await recency.recordOpen(beyond),
        AppOpenRecencyResult.passwordRequired,
      );
      expect(await biometrics.loadValidEnrollment(), isNull);
      expect(memory.values[secure.lastOpenKey], beyond.toIso8601String());
    },
  );

  test('a legacy enrollment with no last-open time is cleared', () async {
    final now = DateTime.utc(2026, 10, 15);

    expect(
      await recency.recordOpen(now),
      AppOpenRecencyResult.passwordRequired,
    );

    expect(await biometrics.loadValidEnrollment(), isNull);
    expect(memory.values[secure.lastOpenKey], now.toIso8601String());
  });

  test(
    'failed cleanup keeps the old time and blocks biometrics on later opens',
    () async {
      final lastOpen = DateTime.utc(2026, 1, 1);
      seedLastOpen(lastOpen);
      memory.failDeletes.add(secure.biometricKey(BiometricStorageKey.enabled));

      expect(
        await recency.recordOpen(DateTime.utc(2026, 10, 15)),
        AppOpenRecencyResult.passwordRequired,
      );
      expect(
        await recency.recordOpen(DateTime.utc(2026, 10, 16)),
        AppOpenRecencyResult.passwordRequired,
      );

      expect(recency.biometricsBlocked, isTrue);
      expect(memory.values[secure.lastOpenKey], lastOpen.toIso8601String());
    },
  );
}
