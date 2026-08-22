import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../../utils/auth_input.dart';
import '../model/auth_responses.dart';

enum TestOtpFlow {
  signup,
  passwordRecovery,
  pinRecovery,
  newDeviceLogin,
  identifierVerification,
}

class TestOtpHint extends Equatable {
  const TestOtpHint({
    required this.flow,
    required this.code,
    required this.expiresAt,
  });

  final TestOtpFlow flow;
  final String code;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  @override
  List<Object?> get props => [flow, code, expiresAt];

  @override
  String toString() =>
      'TestOtpHint(flow: $flow, code: <redacted>, expiresAt: $expiresAt)';
}

final testOtpProvider =
    NotifierProvider<TestOtpNotifier, Map<TestOtpFlow, TestOtpHint>>(
      TestOtpNotifier.new,
    );

class TestOtpNotifier extends Notifier<Map<TestOtpFlow, TestOtpHint>> {
  final Map<TestOtpFlow, Timer> _timers = {};

  @override
  Map<TestOtpFlow, TestOtpHint> build() {
    ref.onDispose(() {
      for (final timer in _timers.values) {
        timer.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  void show(TestOtpFlow flow, OtpData otpData) {
    if (!ref.read(stagingModeProvider)) return;
    final code = otpData.otpCode;
    if (code == null || !isValidOtpCode(code)) return;
    final expiresAt = otpData.expiresAt.toUtc();
    if (!DateTime.now().toUtc().isBefore(expiresAt)) return;

    _timers.remove(flow)?.cancel();
    state = {
      ...state,
      flow: TestOtpHint(flow: flow, code: code, expiresAt: expiresAt),
    };
    _timers[flow] = Timer(expiresAt.difference(DateTime.now().toUtc()), () {
      clear(flow);
    });
  }

  void clear(TestOtpFlow flow) {
    _timers.remove(flow)?.cancel();
    if (!state.containsKey(flow)) return;
    final next = Map<TestOtpFlow, TestOtpHint>.of(state)..remove(flow);
    state = Map.unmodifiable(next);
  }

  void clearAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    state = const {};
  }
}
