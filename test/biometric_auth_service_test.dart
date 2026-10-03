import 'dart:async';

import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

class _FakeLocalAuth extends LocalAuthentication {
  bool deviceSupported = true;
  bool canCheck = true;
  List<BiometricType> available = [BiometricType.fingerprint];
  Object? authError;
  bool authResult = true;
  bool? lastBiometricOnly;
  bool? lastPersist;
  String? lastReason;
  int stopCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => deviceSupported;

  @override
  Future<bool> get canCheckBiometrics async => canCheck;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => available;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages = const <Object>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    lastReason = localizedReason;
    lastBiometricOnly = biometricOnly;
    lastPersist = persistAcrossBackgrounding;
    if (authError != null) throw authError!;
    return authResult;
  }

  @override
  Future<bool> stopAuthentication() async {
    stopCalls++;
    return true;
  }
}

class _ScriptedGateway implements BiometricAuthGateway {
  Completer<BiometricAuthOutcome>? pending;
  int authenticateCalls = 0;

  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) {
    authenticateCalls++;
    pending = Completer<BiometricAuthOutcome>();
    return pending!.future;
  }

  @override
  Future<void> stopAuthentication() async {}
}

void main() {
  late _FakeLocalAuth auth;

  LocalAuthBiometricGateway gateway(
    TargetPlatform platform, {
    bool web = false,
  }) => LocalAuthBiometricGateway(auth: auth, platform: platform, isWeb: web);

  setUp(() => auth = _FakeLocalAuth());

  group('capability', () {
    test('web and desktop are unsupported', () async {
      for (final g in [
        gateway(TargetPlatform.android, web: true),
        gateway(TargetPlatform.macOS),
        gateway(TargetPlatform.windows),
        gateway(TargetPlatform.linux),
      ]) {
        final capability = await g.checkCapability();
        expect(capability.supported, isFalse);
        expect(capability.presentation, isNull);
      }
    });

    test('a device without biometric hardware is unsupported', () async {
      auth.deviceSupported = false;
      final capability = await gateway(
        TargetPlatform.android,
      ).checkCapability();
      expect(capability.supported, isFalse);
      expect(capability.reason, isNotNull);
    });

    test(
      'hardware with nothing enrolled is unsupported with a reason',
      () async {
        auth.available = [];
        final capability = await gateway(TargetPlatform.iOS).checkCapability();
        expect(capability.supported, isFalse);
        expect(capability.reason, contains('Set up'));
      },
    );

    test('iOS face is Face ID', () async {
      auth.available = [BiometricType.face];
      final capability = await gateway(TargetPlatform.iOS).checkCapability();
      expect(capability.supported, isTrue);
      expect(capability.presentation, BiometricPresentation.faceId);
    });

    test('iOS fingerprint is Touch ID', () async {
      auth.available = [BiometricType.fingerprint];
      final capability = await gateway(TargetPlatform.iOS).checkCapability();
      expect(capability.presentation, BiometricPresentation.touchId);
    });

    test('Android enrolled biometrics are fingerprint', () async {
      for (final types in [
        [BiometricType.fingerprint],
        [BiometricType.strong],
        [BiometricType.weak, BiometricType.strong],
      ]) {
        auth.available = types;
        final capability = await gateway(
          TargetPlatform.android,
        ).checkCapability();
        expect(capability.supported, isTrue);
        expect(capability.presentation, BiometricPresentation.fingerprint);
      }
    });
  });

  group('authenticate', () {
    test('success requires biometric-only authentication', () async {
      final outcome = await gateway(
        TargetPlatform.android,
      ).authenticate(reason: 'Sign in to BOCTRUST');
      expect(outcome, BiometricAuthOutcome.success);
      expect(auth.lastBiometricOnly, isTrue);
      expect(auth.lastPersist, isTrue);
      expect(auth.lastReason, 'Sign in to BOCTRUST');
    });

    test('a false result is a failure', () async {
      auth.authResult = false;
      expect(
        await gateway(TargetPlatform.android).authenticate(reason: 'x'),
        BiometricAuthOutcome.failure,
      );
    });

    test('plugin exception codes map to domain outcomes', () async {
      const expected = {
        LocalAuthExceptionCode.userCanceled: BiometricAuthOutcome.cancelled,
        LocalAuthExceptionCode.systemCanceled: BiometricAuthOutcome.cancelled,
        LocalAuthExceptionCode.timeout: BiometricAuthOutcome.cancelled,
        LocalAuthExceptionCode.userRequestedFallback:
            BiometricAuthOutcome.cancelled,
        LocalAuthExceptionCode.temporaryLockout:
            BiometricAuthOutcome.temporaryLockout,
        LocalAuthExceptionCode.biometricLockout:
            BiometricAuthOutcome.permanentLockout,
        LocalAuthExceptionCode.noBiometricsEnrolled:
            BiometricAuthOutcome.notEnrolled,
        LocalAuthExceptionCode.noCredentialsSet:
            BiometricAuthOutcome.notEnrolled,
        LocalAuthExceptionCode.noBiometricHardware:
            BiometricAuthOutcome.unavailable,
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
            BiometricAuthOutcome.unavailable,
        LocalAuthExceptionCode.uiUnavailable: BiometricAuthOutcome.unavailable,
        LocalAuthExceptionCode.authInProgress: BiometricAuthOutcome.failure,
        LocalAuthExceptionCode.deviceError: BiometricAuthOutcome.failure,
        LocalAuthExceptionCode.unknownError: BiometricAuthOutcome.failure,
      };
      for (final entry in expected.entries) {
        auth.authError = LocalAuthException(code: entry.key);
        expect(
          await gateway(TargetPlatform.iOS).authenticate(reason: 'x'),
          entry.value,
          reason: entry.key.name,
        );
      }
    });

    test('an unknown plugin failure is a failure', () async {
      auth.authError = StateError('boom');
      expect(
        await gateway(TargetPlatform.iOS).authenticate(reason: 'x'),
        BiometricAuthOutcome.failure,
      );
    });

    test('unsupported platforms never prompt', () async {
      expect(
        await gateway(TargetPlatform.macOS).authenticate(reason: 'x'),
        BiometricAuthOutcome.unsupported,
      );
      expect(auth.lastReason, isNull);
    });
  });

  group('service', () {
    test(
      'a second prompt while one is active fails without prompting',
      () async {
        final scripted = _ScriptedGateway();
        final service = BiometricAuthService(scripted);

        final first = service.authenticate(reason: 'x');
        final second = await service.authenticate(reason: 'x');

        expect(second, BiometricAuthOutcome.failure);
        expect(scripted.authenticateCalls, 1);

        scripted.pending!.complete(BiometricAuthOutcome.success);
        expect(await first, BiometricAuthOutcome.success);

        final third = service.authenticate(reason: 'x');
        expect(scripted.authenticateCalls, 2);
        scripted.pending!.complete(BiometricAuthOutcome.cancelled);
        expect(await third, BiometricAuthOutcome.cancelled);
      },
    );

    test('stop delegates to the gateway', () async {
      final service = BiometricAuthService(gateway(TargetPlatform.android));
      await service.stopAuthentication();
      expect(auth.stopCalls, 1);
    });
  });
}
