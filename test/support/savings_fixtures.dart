import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_session.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';

AuthSession savingsSession({String user = 'layout'}) => AuthSession(
  accessToken: 'synthetic-$user',
  userId: user,
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  identifierType: IdentifierType.email,
);

class SavingsSession extends AuthSessionNotifier {
  @override
  AuthSession? build() => savingsSession();
  void setSession(AuthSession? session) => state = session;
  @override
  Future<void> clear() async {
    state = null;
  }
}

class SignedOutSavingsSession extends SavingsSession {
  @override
  AuthSession? build() => null;
}
