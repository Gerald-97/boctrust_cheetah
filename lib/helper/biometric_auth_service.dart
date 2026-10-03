import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../module/onboarding/model/remembered_biometric_profile.dart';

/// Whether this device can use biometric login, and how to present it.
class BiometricCapability {
  const BiometricCapability({
    required this.supported,
    required this.presentation,
    required this.reason,
  });

  const BiometricCapability.unsupported(String this.reason)
    : supported = false,
      presentation = null;

  final bool supported;
  final BiometricPresentation? presentation;

  /// Customer-facing explanation when [supported] is false.
  final String? reason;
}

enum BiometricAuthOutcome {
  success,
  cancelled,
  temporaryLockout,
  permanentLockout,
  unavailable,
  notEnrolled,
  unsupported,
  failure,
}

abstract class BiometricAuthGateway {
  Future<BiometricCapability> checkCapability();
  Future<BiometricAuthOutcome> authenticate({required String reason});
  Future<void> stopAuthentication();
}

/// The only class that talks to `local_auth`.
class LocalAuthBiometricGateway implements BiometricAuthGateway {
  LocalAuthBiometricGateway({
    LocalAuthentication? auth,
    TargetPlatform? platform,
    this.isWeb = kIsWeb,
  }) : _auth = auth ?? LocalAuthentication(),
       _platform = platform ?? defaultTargetPlatform;

  final LocalAuthentication _auth;
  final TargetPlatform _platform;
  final bool isWeb;

  bool get _isMobile =>
      !isWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.android);

  static const _unsupportedReason =
      'Biometric login is available on the BOCTRUST iOS and Android apps.';
  static const _noHardwareReason =
      'This device does not support Face ID, Touch ID, or fingerprint login.';
  static const _notEnrolledReason =
      'Set up Face ID, Touch ID, or fingerprint in your device settings to '
      'use biometric login.';

  @override
  Future<BiometricCapability> checkCapability() async {
    if (!_isMobile) {
      return const BiometricCapability.unsupported(_unsupportedReason);
    }
    try {
      if (!await _auth.isDeviceSupported() || !await _auth.canCheckBiometrics) {
        return const BiometricCapability.unsupported(_noHardwareReason);
      }
      final available = await _auth.getAvailableBiometrics();
      final presentation = _presentationFor(available);
      if (presentation == null) {
        return const BiometricCapability.unsupported(_notEnrolledReason);
      }
      return BiometricCapability(
        supported: true,
        presentation: presentation,
        reason: null,
      );
    } catch (_) {
      return const BiometricCapability.unsupported(_noHardwareReason);
    }
  }

  BiometricPresentation? _presentationFor(List<BiometricType> available) {
    if (available.isEmpty) return null;
    if (_platform == TargetPlatform.iOS) {
      if (available.contains(BiometricType.face)) {
        return BiometricPresentation.faceId;
      }
      if (available.contains(BiometricType.fingerprint)) {
        return BiometricPresentation.touchId;
      }
      return null;
    }
    return BiometricPresentation.fingerprint;
  }

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) async {
    if (!_isMobile) return BiometricAuthOutcome.unsupported;
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return authenticated
          ? BiometricAuthOutcome.success
          : BiometricAuthOutcome.failure;
    } on LocalAuthException catch (error) {
      return _outcomeFor(error.code);
    } catch (_) {
      return BiometricAuthOutcome.failure;
    }
  }

  static BiometricAuthOutcome _outcomeFor(
    LocalAuthExceptionCode code,
  ) => switch (code) {
    LocalAuthExceptionCode.userCanceled ||
    LocalAuthExceptionCode.systemCanceled ||
    LocalAuthExceptionCode.timeout ||
    LocalAuthExceptionCode.userRequestedFallback =>
      BiometricAuthOutcome.cancelled,
    LocalAuthExceptionCode.temporaryLockout =>
      BiometricAuthOutcome.temporaryLockout,
    LocalAuthExceptionCode.biometricLockout =>
      BiometricAuthOutcome.permanentLockout,
    LocalAuthExceptionCode.noBiometricsEnrolled ||
    LocalAuthExceptionCode.noCredentialsSet => BiometricAuthOutcome.notEnrolled,
    LocalAuthExceptionCode.noBiometricHardware ||
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable ||
    LocalAuthExceptionCode.uiUnavailable => BiometricAuthOutcome.unavailable,
    LocalAuthExceptionCode.authInProgress ||
    LocalAuthExceptionCode.deviceError ||
    LocalAuthExceptionCode.unknownError => BiometricAuthOutcome.failure,
  };

  @override
  Future<void> stopAuthentication() async {
    if (!_isMobile) return;
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // Nothing to stop.
    }
  }
}

final biometricAuthGatewayProvider = Provider<BiometricAuthGateway>(
  (ref) => LocalAuthBiometricGateway(),
);

final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => BiometricAuthService(ref.watch(biometricAuthGatewayProvider)),
);

/// Allows at most one biometric prompt at a time.
class BiometricAuthService {
  BiometricAuthService(this._gateway);

  final BiometricAuthGateway _gateway;
  bool _prompting = false;

  Future<BiometricCapability> checkCapability() => _gateway.checkCapability();

  Future<BiometricAuthOutcome> authenticate({required String reason}) async {
    if (_prompting) return BiometricAuthOutcome.failure;
    _prompting = true;
    try {
      return await _gateway.authenticate(reason: reason);
    } finally {
      _prompting = false;
    }
  }

  Future<void> stopAuthentication() => _gateway.stopAuthentication();
}
