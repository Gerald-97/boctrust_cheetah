import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/secure_storage.dart';
import '../model/auth_session.dart';

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

  Future<StoredSessionResult> hydrate() async {
    final storage = ref.read(secureStorageProvider);
    try {
      await storage.deleteLegacySessionKeys();
      final result = await storage.readSessionResult();
      state = result.session;
      if (result.status == StoredSessionStatus.invalid ||
          result.status == StoredSessionStatus.expired) {
        await storage.clearAuthSession();
      }
      return result;
    } catch (_) {
      state = null;
      try {
        await storage.clearAuthSession();
      } catch (_) {
        // The startup gate still routes to sign-in if secure storage is down.
      }
      return (status: StoredSessionStatus.invalid, session: null);
    }
  }

  Future<bool> establish(AuthSession session) async {
    try {
      await ref.read(secureStorageProvider).writeSession(session);
      state = session;
      return true;
    } catch (_) {
      state = null;
      return false;
    }
  }

  Future<void> clear() async {
    state = null;
    await ref.read(secureStorageProvider).clearAuthSession();
  }
}
