import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hasSeenOnboardingKey = 'boctrust.has_seen_onboarding';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided at bootstrap.');
});

/// Per-user preference keys, so one customer's settings never apply to the
/// next person who signs in on this device.
String notificationPreferencesKey(String userId) =>
    'boctrust.prefs.$userId.notifications';
String accessibilityPreferencesKey(String userId) =>
    'boctrust.prefs.$userId.accessibility';
