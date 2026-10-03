import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';

import 'memory_secure_storage.dart';

/// Widget tests cannot reach the biometric or secure-storage plugins; these
/// overrides make the device report no biometrics and no enrollment.
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

List<dynamic> biometricTestOverrides() => [
  biometricAuthGatewayProvider.overrideWithValue(UnsupportedBiometricGateway()),
  biometricLoginStorageProvider.overrideWithValue(
    BiometricLoginStorage(SecureStorage(storage: MemorySecureStorage())),
  ),
];
