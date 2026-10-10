import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_initiation.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _reply({
  Object? reference = 'a1b2c3d4e5f6',
  Object? checks = const ['pin', 'otp'],
  Object? expiresAt = '2026-10-10T12:05:00Z',
}) => {
  'reference': reference,
  'requiredChecks': checks,
  'expiresAt': expiresAt,
};

void main() {
  test('reads the reference, checks and UTC expiry', () {
    final initiation = CoreTransferInitiation.fromJson(_reply());

    expect(initiation.reference, 'a1b2c3d4e5f6');
    expect(initiation.checks, {CoreTransferCheck.pin, CoreTransferCheck.otp});
    expect(initiation.expiresAt, DateTime.utc(2026, 10, 10, 12, 5));
    expect(initiation.supported, isTrue);
    expect(initiation.isExpiredAt(DateTime.utc(2026, 10, 10, 12, 5)), isTrue);
  });

  test('liveness is understood but not supported', () {
    final initiation = CoreTransferInitiation.fromJson(
      _reply(checks: ['pin', 'liveness']),
    );

    expect(initiation.supported, isFalse);
  });

  for (final (name, reply) in [
    ('malformed reference', _reply(reference: 'REF/1')),
    ('missing pin', _reply(checks: ['otp'])),
    ('no checks', _reply(checks: <String>[])),
    ('duplicate check', _reply(checks: ['pin', 'pin'])),
    ('unknown check', _reply(checks: ['pin', 'selfie'])),
    ('invalid expiry', _reply(expiresAt: 'soon')),
  ]) {
    test('rejects a $name', () {
      expect(
        () => CoreTransferInitiation.fromJson(reply),
        throwsFormatException,
      );
    });
  }
}
