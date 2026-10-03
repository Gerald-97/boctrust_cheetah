import 'dart:convert';

import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  late BiometricLoginStorage storage;

  String key(BiometricStorageKey k) => secure.biometricKey(k);
  List<String> allKeys() => BiometricStorageKey.values.map(key).toList();

  setUp(() {
    memory = MemorySecureStorage();
    secure = SecureStorage(storage: memory);
    storage = BiometricLoginStorage(secure);
  });

  Future<void> enable() => storage.enable(
    profile: _profile,
    identifier: '0803 123 4567',
    password: 'Secret#123',
  );

  test(
    'enable writes password identifier profile and enabled marker in order',
    () async {
      await enable();

      expect(memory.writes, [
        key(BiometricStorageKey.password),
        key(BiometricStorageKey.identifier),
        key(BiometricStorageKey.profile),
        key(BiometricStorageKey.enabled),
      ]);
      expect(
        memory.values[key(BiometricStorageKey.identifier)],
        '+2348031234567',
      );
      expect(memory.values[key(BiometricStorageKey.password)], 'Secret#123');
      final profileJson = memory.values[key(BiometricStorageKey.profile)]!;
      expect(profileJson.contains('Secret#123'), isFalse);
      expect(
        RememberedBiometricProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(profileJson) as Map),
        ),
        _profile,
      );
    },
  );

  test('enable replaces a previous enrollment by deleting it first', () async {
    await enable();
    memory.writes.clear();
    memory.deletes.clear();

    await enable();

    expect(memory.deletes.toSet(), allKeys().toSet());
    expect(memory.writes.first, key(BiometricStorageKey.password));
  });

  test(
    'failure at each enrollment write rolls back every biometric key',
    () async {
      for (final failing in [
        BiometricStorageKey.password,
        BiometricStorageKey.identifier,
        BiometricStorageKey.profile,
        BiometricStorageKey.enabled,
      ]) {
        memory = MemorySecureStorage()..failWrites.add(key(failing));
        secure = SecureStorage(storage: memory);
        storage = BiometricLoginStorage(secure);

        await expectLater(enable(), throwsA(isA<BiometricStorageException>()));
        for (final k in allKeys()) {
          expect(
            memory.values.containsKey(k),
            isFalse,
            reason: '$failing → $k',
          );
        }
        expect(await storage.loadValidEnrollment(), isNull);
      }
    },
  );

  test('storage exception carries no secret values', () async {
    memory.failWrites.add(key(BiometricStorageKey.profile));
    try {
      await enable();
      fail('expected failure');
    } on BiometricStorageException catch (error) {
      expect(error.toString().contains('Secret#123'), isFalse);
      expect(error.toString().contains('2348031234567'), isFalse);
    }
  });

  test('enable rejects an identifier that differs from the profile', () async {
    await expectLater(
      storage.enable(
        profile: _profile,
        identifier: 'someone@example.com',
        password: 'Secret#123',
      ),
      throwsA(isA<BiometricStorageException>()),
    );
    expect(memory.values, isEmpty);
  });

  test(
    'load rejects unsupported malformed missing and mismatched state',
    () async {
      final corruptions = <String, void Function()>{
        'enabled marker not true': () =>
            memory.values[key(BiometricStorageKey.enabled)] = 'false',
        'missing password': () =>
            memory.values.remove(key(BiometricStorageKey.password)),
        'missing identifier': () =>
            memory.values.remove(key(BiometricStorageKey.identifier)),
        'missing profile': () =>
            memory.values.remove(key(BiometricStorageKey.profile)),
        'malformed profile': () =>
            memory.values[key(BiometricStorageKey.profile)] = '{not json',
        'unsupported schema': () =>
            memory.values[key(BiometricStorageKey.profile)] = jsonEncode({
              ..._profile.toJson(),
              'schemaVersion': 9,
            }),
        'identifier mismatch': () =>
            memory.values[key(BiometricStorageKey.identifier)] =
                '+2348000000000',
        'missing enabled marker': () =>
            memory.values.remove(key(BiometricStorageKey.enabled)),
      };
      for (final entry in corruptions.entries) {
        memory.values.clear();
        await enable();
        entry.value();

        expect(await storage.loadValidEnrollment(), isNull, reason: entry.key);
        for (final k in allKeys()) {
          expect(memory.values.containsKey(k), isFalse, reason: entry.key);
        }
      }
    },
  );

  test('load returns null and touches nothing when never enrolled', () async {
    expect(await storage.loadValidEnrollment(), isNull);
    expect(memory.deletes, isEmpty);
  });

  test(
    'load returns profile without reading a credential into provider state',
    () async {
      await enable();
      memory.reads.clear();

      final enrollment = await storage.loadValidEnrollment();

      expect(enrollment?.profile, _profile);
      expect(memory.reads.contains(key(BiometricStorageKey.password)), isFalse);
    },
  );

  test(
    'load treats a throwing secure read as invalid and clears enrollment',
    () async {
      await enable();
      memory.failReads.add(key(BiometricStorageKey.profile));

      expect(await storage.loadValidEnrollment(), isNull);
      memory.failReads.clear();
      for (final k in allKeys()) {
        expect(memory.values.containsKey(k), isFalse);
      }
    },
  );

  test(
    'credential read returns data only through the post-authentication method',
    () async {
      await enable();

      final credential = await storage.readCredentialAfterAuthentication();

      expect(credential?.identifier, '+2348031234567');
      expect(credential?.password, 'Secret#123');
      expect(credential.toString().contains('Secret#123'), isFalse);
    },
  );

  test(
    'credential read returns null and clears on inconsistent state',
    () async {
      await enable();
      memory.values[key(BiometricStorageKey.identifier)] = '+2348000000000';

      expect(await storage.readCredentialAfterAuthentication(), isNull);
      expect(
        memory.values.containsKey(key(BiometricStorageKey.password)),
        isFalse,
      );
    },
  );

  test(
    'clear attempts every key after a deletion failure and is idempotent',
    () async {
      await enable();
      memory.failDeletes.add(key(BiometricStorageKey.profile));

      final result = await storage.clearEnrollment();

      expect(result.isComplete, isFalse);
      expect(result.failedKeys, [key(BiometricStorageKey.profile)]);
      expect(memory.deletes.toSet(), allKeys().toSet());
      expect(memory.deletes.first, key(BiometricStorageKey.enabled));

      memory.failDeletes.clear();
      expect((await storage.clearEnrollment()).isComplete, isTrue);
      expect((await storage.clearEnrollment()).isComplete, isTrue);
      expect(memory.values, isEmpty);
    },
  );

  test(
    'replace credential refuses an identifier different from the remembered profile',
    () async {
      await enable();

      await expectLater(
        storage.replaceCredential(
          identifier: '+2348000000000',
          password: 'Other#123',
        ),
        throwsA(isA<BiometricStorageException>()),
      );
      expect(memory.values[key(BiometricStorageKey.password)], 'Secret#123');

      await storage.replaceCredential(
        identifier: '08031234567',
        password: 'New#12345',
      );
      expect(memory.values[key(BiometricStorageKey.password)], 'New#12345');
    },
  );

  test(
    'biometric keys are written with device-only keychain accessibility',
    () async {
      await enable();

      for (final k in allKeys()) {
        expect(
          memory.writeOptions[k]?.accessibility,
          KeychainAccessibility.unlocked_this_device,
          reason: k,
        );
      }
    },
  );

  test('biometric keys are namespaced and versioned', () {
    for (final k in allKeys()) {
      expect(k, contains('.biometric.v1.'));
    }
  });
}
