import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../helper/secure_storage.dart';
import '../model/auth_session.dart';

final authSessionProvider = NotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends Notifier<AuthSession?> {
  @override
  AuthSession? build() => null;

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
