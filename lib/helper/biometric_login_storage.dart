import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../module/onboarding/model/remembered_biometric_profile.dart';
import '../utils/auth_input.dart';
import 'secure_storage.dart';

final biometricLoginStorageProvider = Provider<BiometricLoginStorage>(
  (ref) => BiometricLoginStorage(ref.watch(secureStorageProvider)),
);

/// A saved login credential, released only after biometric authentication.
///
/// Deliberately has no equality, JSON, or descriptive `toString`.
class BiometricCredential {
  const BiometricCredential({required this.identifier, required this.password});
  final String identifier;
  final String password;
}

/// A consistent enrollment as seen by the UI: the profile only, never the
/// password.
class BiometricEnrollment {
  const BiometricEnrollment({required this.profile});
  final RememberedBiometricProfile profile;
}

class BiometricCleanupResult {
  const BiometricCleanupResult({required this.failedKeys});
  final List<String> failedKeys;
  bool get isComplete => failedKeys.isEmpty;
}

/// A storage failure whose message never contains a stored value.
class BiometricStorageException implements Exception {
  const BiometricStorageException(this.message);
  final String message;

  @override
  String toString() => 'BiometricStorageException: $message';
}

/// Coordinates the four secure-storage keys of one biometric enrollment so it
/// is either fully present and consistent or absent.
class BiometricLoginStorage {
  BiometricLoginStorage(this._storage);

  final SecureStorage _storage;

  /// Replaces any previous enrollment. The enabled marker is written last, so
  /// an interrupted enrollment never reads as enabled.
  Future<void> enable({
    required RememberedBiometricProfile profile,
    required String identifier,
    required String password,
  }) async {
    final normalized = normalizeIdentifier(identifier);
    if (!profile.isValid || normalized != profile.identifier) {
      throw const BiometricStorageException(
        'The credential does not match the remembered account.',
      );
    }
    if (password.isEmpty) {
      throw const BiometricStorageException('A password is required.');
    }
    await clearEnrollment();
    try {
      await _storage.writeBiometricValue(
        BiometricStorageKey.password,
        password,
      );
      await _storage.writeBiometricValue(
        BiometricStorageKey.identifier,
        normalized,
      );
      await _storage.writeBiometricValue(
        BiometricStorageKey.profile,
        jsonEncode(profile.toJson()),
      );
      await _storage.writeBiometricValue(BiometricStorageKey.enabled, 'true');
    } catch (_) {
      await clearEnrollment();
      throw const BiometricStorageException(
        'Biometric login could not be saved on this device.',
      );
    }
  }

  /// Returns the enrollment when every key is present and consistent. Any
  /// other state, including values that no longer decrypt, is cleared.
  Future<BiometricEnrollment?> loadValidEnrollment() async {
    try {
      final enabled = await _storage.readBiometricValue(
        BiometricStorageKey.enabled,
      );
      final rawProfile = await _storage.readBiometricValue(
        BiometricStorageKey.profile,
      );
      final identifier = await _storage.readBiometricValue(
        BiometricStorageKey.identifier,
      );
      final hasPassword = await _storage.hasBiometricValue(
        BiometricStorageKey.password,
      );
      if (enabled == null &&
          rawProfile == null &&
          identifier == null &&
          !hasPassword) {
        return null;
      }
      if (enabled != 'true' ||
          rawProfile == null ||
          identifier == null ||
          !hasPassword) {
        await clearEnrollment();
        return null;
      }
      final json = jsonDecode(rawProfile);
      if (json is! Map) throw const FormatException();
      final profile = RememberedBiometricProfile.fromJson(
        Map<String, Object?>.from(json),
      );
      if (profile.identifier != identifier) throw const FormatException();
      return BiometricEnrollment(profile: profile);
    } catch (_) {
      await clearEnrollment();
      return null;
    }
  }

  /// Call only after the biometric prompt succeeded.
  Future<BiometricCredential?> readCredentialAfterAuthentication() async {
    final enrollment = await loadValidEnrollment();
    if (enrollment == null) return null;
    try {
      final password = await _storage.readBiometricValue(
        BiometricStorageKey.password,
      );
      if (password == null || password.isEmpty) {
        await clearEnrollment();
        return null;
      }
      return BiometricCredential(
        identifier: enrollment.profile.identifier,
        password: password,
      );
    } catch (_) {
      await clearEnrollment();
      return null;
    }
  }

  /// Updates the saved password after a successful manual login for the same
  /// remembered account.
  Future<void> replaceCredential({
    required String identifier,
    required String password,
  }) async {
    final enrollment = await loadValidEnrollment();
    if (enrollment == null ||
        normalizeIdentifier(identifier) != enrollment.profile.identifier ||
        password.isEmpty) {
      throw const BiometricStorageException(
        'The credential does not match the remembered account.',
      );
    }
    try {
      await _storage.writeBiometricValue(
        BiometricStorageKey.password,
        password,
      );
    } catch (_) {
      throw const BiometricStorageException(
        'The saved password could not be updated.',
      );
    }
  }

  /// Deletes the enabled marker first, then every other key, attempting all of
  /// them even when one fails.
  Future<BiometricCleanupResult> clearEnrollment() async {
    final failed = <String>[];
    for (final key in const [
      BiometricStorageKey.enabled,
      BiometricStorageKey.profile,
      BiometricStorageKey.identifier,
      BiometricStorageKey.password,
    ]) {
      try {
        await _storage.deleteBiometricValue(key);
      } catch (_) {
        failed.add(_storage.biometricKey(key));
      }
    }
    return BiometricCleanupResult(failedKeys: failed);
  }
}
