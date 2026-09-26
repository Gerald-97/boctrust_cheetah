import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/preferences.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/account_preferences.dart';

/// Reads a JSON map saved under [key], or null when absent or unreadable.
Map<String, Object?>? _readJson(Ref ref, String key) {
  final raw = ref.read(sharedPreferencesProvider).getString(key);
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// Accessibility settings for the signed-in customer. Signed out, everyone
/// gets the defaults; switching customer reloads that customer's settings.
final accessibilityPreferencesProvider =
    NotifierProvider<
      AccessibilityPreferencesNotifier,
      AccessibilityPreferences
    >(AccessibilityPreferencesNotifier.new);

class AccessibilityPreferencesNotifier
    extends Notifier<AccessibilityPreferences> {
  String? get _userId => ref.read(authSessionProvider)?.userId;

  @override
  AccessibilityPreferences build() {
    final userId = ref.watch(
      authSessionProvider.select((session) => session?.userId),
    );
    if (userId == null) return const AccessibilityPreferences();
    final json = _readJson(ref, accessibilityPreferencesKey(userId));
    return json == null
        ? const AccessibilityPreferences()
        : AccessibilityPreferences.fromJson(json);
  }

  Future<void> update(AccessibilityPreferences next) async {
    state = next;
    final userId = _userId;
    if (userId == null) return;
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          accessibilityPreferencesKey(userId),
          jsonEncode(next.toJson()),
        );
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );

class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  String? get _userId => ref.read(authSessionProvider)?.userId;

  @override
  NotificationPreferences build() {
    final userId = ref.watch(
      authSessionProvider.select((session) => session?.userId),
    );
    if (userId == null) return const NotificationPreferences();
    final json = _readJson(ref, notificationPreferencesKey(userId));
    return json == null
        ? const NotificationPreferences()
        : NotificationPreferences.fromJson(json);
  }

  Future<void> update(NotificationPreferences next) async {
    state = next;
    final userId = _userId;
    if (userId == null) return;
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          notificationPreferencesKey(userId),
          jsonEncode(next.toJson()),
        );
  }
}
