import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../app/services.dart';
import '../module/onboarding/model/auth_session.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

enum StoredSessionStatus { absent, valid, invalid, expired }

typedef StoredSessionResult = ({
  StoredSessionStatus status,
  AuthSession? session,
});

class SecureStorage {
  SecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String get _prefix => Env.secureStorageNamespace;
  String get accessTokenKey => '$_prefix.access_token';
  String get authSessionKey => '$_prefix.auth_session';
  String get deviceTokenKey => '$_prefix.device_token';

  static const _legacyKeys = <String>[
    'boctrust.access_token',
    'boctrust.refresh_token',
    'boctrust.biometric_credentials',
    'boctrust.transaction_pin_metadata',
    'boctrust.profile_cache',
  ];

  Future<void> deleteLegacySessionKeys() async {
    for (final key in _legacyKeys) {
      await _storage.delete(key: key);
    }
  }

  Future<void> writeSession(AuthSession session) async {
    try {
      await _storage.write(
        key: authSessionKey,
        value: jsonEncode(session.metadata.toJson()),
      );
      await _storage.write(key: accessTokenKey, value: session.accessToken);
    } catch (_) {
      await clearAuthSession();
      rethrow;
    }
  }

  Future<StoredSessionResult> readSessionResult() async {
    final token = await readAccessToken();
    final rawMetadata = await _storage.read(key: authSessionKey);
    if (token == null && rawMetadata == null) {
      return (status: StoredSessionStatus.absent, session: null);
    }
    if (token == null || token.trim().isEmpty || rawMetadata == null) {
      return (status: StoredSessionStatus.invalid, session: null);
    }

    try {
      final json = jsonDecode(rawMetadata);
      if (json is! Map) {
        return (status: StoredSessionStatus.invalid, session: null);
      }
      final metadata = PersistedSessionMetadata.fromJson(
        Map<String, Object?>.from(json),
      );
      if (metadata.schemaVersion != 1 ||
          metadata.userId.trim().isEmpty ||
          metadata.identifierType.name == 'unknown') {
        return (status: StoredSessionStatus.invalid, session: null);
      }
      if (!metadata.expiresAt.isAfter(DateTime.now().toUtc())) {
        return (status: StoredSessionStatus.expired, session: null);
      }
      final session = AuthSession(
        accessToken: token,
        expiresAt: metadata.expiresAt,
        userId: metadata.userId,
        email: metadata.email,
        phoneNumber: metadata.phoneNumber,
        identifierType: metadata.identifierType,
      );
      return (status: StoredSessionStatus.valid, session: session);
    } catch (_) {
      return (status: StoredSessionStatus.invalid, session: null);
    }
  }

  Future<AuthSession?> readSession() async =>
      (await readSessionResult()).session;

  Future<String?> readAccessToken() => _storage.read(key: accessTokenKey);

  Future<void> clearAuthSession() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: authSessionKey);
  }

  Future<String?> readDeviceToken() => _storage.read(key: deviceTokenKey);

  Future<void> writeDeviceToken(String token) =>
      _storage.write(key: deviceTokenKey, value: token);
}
