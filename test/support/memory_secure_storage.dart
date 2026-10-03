import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// In-memory [FlutterSecureStorage] that records every call and can be told
/// to fail on specific operations.
class MemorySecureStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  final reads = <String>[];
  final writes = <String>[];
  final deletes = <String>[];
  final writeOptions = <String, IOSOptions?>{};

  /// Keys whose write, read, or delete throws.
  final failWrites = <String>{};
  final failReads = <String>{};
  final failDeletes = <String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writes.add(key);
    writeOptions[key] = iOptions as IOSOptions?;
    if (failWrites.contains(key)) throw StateError('write failed: $key');
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    reads.add(key);
    if (failReads.contains(key)) throw StateError('read failed: $key');
    return values[key];
  }

  @override
  Future<bool> containsKey({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failReads.contains(key)) throw StateError('read failed: $key');
    return values.containsKey(key);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletes.add(key);
    if (failDeletes.contains(key)) throw StateError('delete failed: $key');
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
