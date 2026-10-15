import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';

import 'memory_secure_storage.dart';

/// Widget tests cannot reach the biometric or secure-storage plugins; these
/// overrides make the device report no biometrics and no enrollment, with the
/// app-open record kept in the same memory.
class UnsupportedBiometricGateway implements BiometricAuthGateway {
  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability.unsupported('Not available in tests.');

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) async =>
      BiometricAuthOutcome.unsupported;

  @override
  Future<void> stopAuthentication() async {}
}

List<dynamic> biometricTestOverrides() {
  final secure = SecureStorage(storage: MemorySecureStorage());
  final biometrics = BiometricLoginStorage(secure);
  // The test binding never reports a foreground lifecycle state, so record
  // the foreground launch the app would otherwise wait for.
  final recency = AppOpenRecency(secure, biometrics)..recordColdLaunch();
  return [
    biometricAuthGatewayProvider.overrideWithValue(
      UnsupportedBiometricGateway(),
    ),
    biometricLoginStorageProvider.overrideWithValue(biometrics),
    appOpenRecencyProvider.overrideWithValue(recency),
  ];
}
