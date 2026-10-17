import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'biometric_login_storage.dart';
import 'biometric_transfer_storage.dart';
import 'secure_storage.dart';

final appOpenRecencyProvider = Provider<AppOpenRecency>(
  (ref) => AppOpenRecency(
    ref.watch(secureStorageProvider),
    ref.watch(biometricLoginStorageProvider),
    ref.watch(biometricTransferStorageProvider),
  ),
);

enum AppOpenRecencyResult { eligible, passwordRequired }

/// Biometric login and transfer approval stay usable only while the app was
/// last opened no more than six calendar months ago.
abstract final class BiometricRecencyPolicy {
  static const months = 6;

  /// The same wall-clock time [months] later, with a missing day clamped to
  /// the last day of that month.
  static DateTime anniversaryOf(DateTime lastOpenUtc) {
    final month = DateTime.utc(lastOpenUtc.year, lastOpenUtc.month + months);
    final lastDay = DateTime.utc(month.year, month.month + 1, 0).day;
    return DateTime.utc(
      month.year,
      month.month,
      min(lastOpenUtc.day, lastDay),
      lastOpenUtc.hour,
      lastOpenUtc.minute,
      lastOpenUtc.second,
      lastOpenUtc.millisecond,
      lastOpenUtc.microsecond,
    );
  }

  /// A future [lastOpenUtc] means the clock moved backward: not recent.
  static bool isRecent(DateTime lastOpenUtc, DateTime nowUtc) =>
      !lastOpenUtc.isAfter(nowUtc) &&
      !nowUtc.isAfter(anniversaryOf(lastOpenUtc));
}

/// Records each app open (a foreground cold launch or a return from the
/// background) and clears both biometric enrollments (login and transfer
/// approval) when the previous open was not recent. A background launch, such
/// as for a push, is not an open.
class AppOpenRecency {
  AppOpenRecency(
    this._storage,
    this._biometrics,
    this._transfers, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SecureStorage _storage;
  final BiometricLoginStorage _biometrics;
  final BiometricTransferStorage _transfers;
  final DateTime Function() _clock;

  Future<AppOpenRecencyResult>? _latest;
  final _opened = Completer<void>();
  bool _cleanupFailed = false;
  bool _readFailed = false;

  /// Blocks both biometric features. True while a stale enrollment could not
  /// be deleted, or for the rest of the process once the last-open time could
  /// not be read. A failed cleanup keeps the old last-open time stale until a
  /// later cleanup succeeds.
  bool get biometricsBlocked => _cleanupFailed || _readFailed;

  /// Records the cold launch unless this process already recorded an open.
  /// Call only while the app is in the foreground.
  Future<AppOpenRecencyResult> recordColdLaunch() =>
      _latest ?? recordOpen(_clock().toUtc());

  Future<AppOpenRecencyResult> recordForegroundOpen() =>
      recordOpen(_clock().toUtc());

  /// The result of the most recent open, waiting for the first foreground
  /// open and for any still in progress.
  Future<AppOpenRecencyResult> latest() async {
    await _opened.future;
    while (true) {
      final pending = _latest!;
      final result = await pending;
      if (identical(pending, _latest)) return result;
    }
  }

  /// Opens are evaluated one at a time, in the order they happened.
  Future<AppOpenRecencyResult> recordOpen(DateTime nowUtc) {
    final previous = _latest;
    if (!_opened.isCompleted) _opened.complete();
    return _latest = () async {
      await previous;
      return _record(nowUtc);
    }();
  }

  Future<AppOpenRecencyResult> _record(DateTime nowUtc) async {
    var recent = false;
    var loginEnrolled = true;
    try {
      final lastOpen = DateTime.tryParse(await _storage.readLastOpen() ?? '');
      recent =
          lastOpen != null &&
          lastOpen.isUtc &&
          BiometricRecencyPolicy.isRecent(lastOpen, nowUtc);
      loginEnrolled = await _storage.hasBiometricValue(
        BiometricStorageKey.enabled,
      );
    } catch (_) {
      // Recency is unknown (for example, a locked keychain): block biometrics
      // for this process but keep a possibly recent enrollment.
      _readFailed = true;
      return AppOpenRecencyResult.passwordRequired;
    }
    final invalidated = !recent || _cleanupFailed;
    if (invalidated) {
      final login = await _biometrics.clearEnrollment();
      final transfer = await _transfers.clearEnrollment();
      _cleanupFailed = !login.isComplete || !transfer.isComplete;
      // Keep the old time so the next open still sees it as stale.
      if (_cleanupFailed) return AppOpenRecencyResult.passwordRequired;
    }
    try {
      await _storage.writeLastOpen(nowUtc.toIso8601String());
    } catch (_) {
      // The older time stays: later opens are judged more strictly, not less.
    }
    // The result drives the login message only: an open with no biometric
    // login enrolled has nothing to explain, even if transfer approval was
    // cleared.
    return invalidated && loginEnrolled
        ? AppOpenRecencyResult.passwordRequired
        : AppOpenRecencyResult.eligible;
  }
}
