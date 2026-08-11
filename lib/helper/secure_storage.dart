import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'boctrust.access_token';
  static const refreshTokenKey = 'boctrust.refresh_token';
  static const biometricCredentialKey = 'boctrust.biometric_credentials';
  static const transactionPinMetadataKey = 'boctrust.transaction_pin_metadata';
  static const profileCacheKey = 'boctrust.profile_cache';

  Future<void> writeAccessToken(String token) =>
      _storage.write(key: accessTokenKey, value: token);
  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: refreshTokenKey, value: token);
  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);
  Future<void> clearSession() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _storage.delete(key: biometricCredentialKey);
    await _storage.delete(key: transactionPinMetadataKey);
    await _storage.delete(key: profileCacheKey);
  }
}
