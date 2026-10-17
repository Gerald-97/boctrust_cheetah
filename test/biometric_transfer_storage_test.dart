import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_storage.dart';

void main() {
  late MemorySecureStorage memory;
  late SecureStorage secure;
  late BiometricTransferStorage storage;

  String key(BiometricTransferStorageKey k) => secure.biometricTransferKey(k);

  setUp(() {
    memory = MemorySecureStorage();
    secure = SecureStorage(storage: memory);
    storage = BiometricTransferStorage(secure);
  });

  test('an interrupted enable never reads as enabled', () async {
    memory.failWrites.add(key(BiometricTransferStorageKey.userId));

    await expectLater(
      storage.enable(userId: 'user-1', pin: '1234'),
      throwsA(isA<BiometricStorageException>()),
    );

    expect(await storage.loadValidEnrollment(), isNull);
    expect(memory.values, isEmpty);
  });

  test('a leading-zero PIN round-trips as a string', () async {
    await storage.enable(userId: 'user-1', pin: '0042');

    expect(await storage.loadValidEnrollment(), 'user-1');
    expect(await storage.readPinAfterAuthentication('user-1'), '0042');
  });

  test(
    'an undecryptable value or mismatched user clears the enrollment',
    () async {
      await storage.enable(userId: 'user-1', pin: '1234');
      memory.failReads.add(key(BiometricTransferStorageKey.pin));
      expect(await storage.readPinAfterAuthentication('user-1'), isNull);
      expect(memory.values, isEmpty);

      memory.failReads.clear();
      await storage.enable(userId: 'user-1', pin: '1234');
      expect(await storage.readPinAfterAuthentication('user-2'), isNull);
      expect(memory.values, isEmpty);
    },
  );
}
