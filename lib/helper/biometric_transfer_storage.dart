import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_login_storage.dart';
import 'secure_storage.dart';

export 'biometric_login_storage.dart'
    show BiometricCleanupResult, BiometricStorageException;

final biometricTransferStorageProvider = Provider<BiometricTransferStorage>(
  (ref) => BiometricTransferStorage(ref.watch(secureStorageProvider)),
);

final _fourDigits = RegExp(r'^\d{4}$');

/// Device-local enrollment for biometric transfer approval. Holds the
/// transaction PIN under its own keys; never exposes it except through
/// [readPinAfterAuthentication].
class BiometricTransferStorage {
  BiometricTransferStorage(this._storage);

  final SecureStorage _storage;

  /// Replaces any previous enrollment. The enabled marker is written last, so
  /// an interrupted enrollment never reads as enabled.
  Future<void> enable({required String userId, required String pin}) async {
    if (userId.isEmpty) {
      throw const BiometricStorageException('A user is required.');
    }
    if (!_fourDigits.hasMatch(pin)) {
      throw const BiometricStorageException('A four-digit PIN is required.');
    }
    await clearEnrollment();
    try {
      await _storage.writeBiometricTransferValue(
        BiometricTransferStorageKey.pin,
        pin,
      );
      await _storage.writeBiometricTransferValue(
        BiometricTransferStorageKey.userId,
        userId,
      );
      await _storage.writeBiometricTransferValue(
        BiometricTransferStorageKey.enabled,
        'true',
      );
    } catch (_) {
      await clearEnrollment();
      throw const BiometricStorageException(
        'Biometric transfer approval could not be saved on this device.',
      );
    }
  }

  /// Cheap check that the enabled marker exists. Does not validate the rest.
  Future<bool> hasEnabledMarker() async {
    try {
      return await _storage.hasBiometricTransferValue(
        BiometricTransferStorageKey.enabled,
      );
    } catch (_) {
      return false;
    }
  }

  /// Returns the enrolled user ID when every key is present and consistent.
  /// Any other state, including values that no longer decrypt, is cleared.
  Future<String?> loadValidEnrollment() async {
    try {
      final enabled = await _storage.readBiometricTransferValue(
        BiometricTransferStorageKey.enabled,
      );
      final userId = await _storage.readBiometricTransferValue(
        BiometricTransferStorageKey.userId,
      );
      final hasPin = await _storage.hasBiometricTransferValue(
        BiometricTransferStorageKey.pin,
      );
      if (enabled == null && userId == null && !hasPin) return null;
      if (enabled != 'true' || userId == null || userId.isEmpty || !hasPin) {
        await clearEnrollment();
        return null;
      }
      return userId;
    } catch (_) {
      await clearEnrollment();
      return null;
    }
  }

  /// Call only after the biometric prompt succeeded.
  Future<String?> readPinAfterAuthentication(String userId) async {
    final enrolled = await loadValidEnrollment();
    if (enrolled == null) return null;
    if (enrolled != userId) {
      await clearEnrollment();
      return null;
    }
    try {
      final pin = await _storage.readBiometricTransferValue(
        BiometricTransferStorageKey.pin,
      );
      if (pin == null || !_fourDigits.hasMatch(pin)) {
        await clearEnrollment();
        return null;
      }
      return pin;
    } catch (_) {
      await clearEnrollment();
      return null;
    }
  }

  /// Deletes the enabled marker first, then every other key, attempting all of
  /// them even when one fails.
  Future<BiometricCleanupResult> clearEnrollment() async {
    final failed = <String>[];
    for (final key in const [
      BiometricTransferStorageKey.enabled,
      BiometricTransferStorageKey.userId,
      BiometricTransferStorageKey.pin,
    ]) {
      try {
        await _storage.deleteBiometricTransferValue(key);
      } catch (_) {
        failed.add(_storage.biometricTransferKey(key));
      }
    }
    return BiometricCleanupResult(failedKeys: failed);
  }
}
