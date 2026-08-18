import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'secure_storage.dart';

final deviceIdentityServiceProvider = Provider<DeviceIdentityService>(
  (ref) => DeviceIdentityService(ref.watch(secureStorageProvider)),
);

class DeviceIdentityService {
  DeviceIdentityService(this._storage);

  final SecureStorage _storage;
  Future<String>? _pendingIdentity;

  Future<String> getOrCreate() async {
    final pending = _pendingIdentity;
    if (pending != null) return pending;

    final attempt = _loadOrCreate();
    _pendingIdentity = attempt;
    try {
      return await attempt;
    } catch (_) {
      if (identical(_pendingIdentity, attempt)) _pendingIdentity = null;
      rethrow;
    }
  }

  Future<String> _loadOrCreate() async {
    final existing = await _storage.readDeviceToken();
    if (existing != null && existing.length >= 8) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    await _storage.writeDeviceToken(token);
    return token;
  }
}
