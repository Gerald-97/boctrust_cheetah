import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The time source for inactivity decisions; tests override it.
final inactivityClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

enum InactivityStatus { active, warning, expired }

/// Signed-in idle limits: a warning after two minutes without activity and
/// logout after three.
abstract final class InactivityPolicy {
  static const warningAfter = Duration(minutes: 2);
  static const expireAfter = Duration(minutes: 3);

  /// Backward clock movement tolerated as network time adjustment.
  static const clockSkew = Duration(seconds: 5);

  static InactivityStatus evaluate(DateTime lastActivity, DateTime now) {
    final idle = now.difference(lastActivity);
    // The clock moved backward: real idle time is unknown, so fail closed.
    if (idle < -clockSkew) return InactivityStatus.expired;
    if (idle >= expireAfter) return InactivityStatus.expired;
    if (idle >= warningAfter) return InactivityStatus.warning;
    return InactivityStatus.active;
  }
}
