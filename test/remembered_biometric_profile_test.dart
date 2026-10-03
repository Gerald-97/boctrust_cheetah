import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _json({
  Object? schemaVersion = 1,
  Object? userId = 'user-1',
  Object? identifier = 'ada@example.com',
  Object? identifierType = 'email',
  Object? firstName = 'Ada',
  Object? biometricType = 'face_id',
}) => {
  'schemaVersion': schemaVersion,
  'userId': userId,
  'identifier': identifier,
  'identifierType': identifierType,
  'firstName': firstName,
  'biometricType': biometricType,
};

void main() {
  test('remembered biometric profile round trips the persisted first name', () {
    const profile = RememberedBiometricProfile(
      userId: 'user-1',
      identifier: 'ada@example.com',
      identifierType: IdentifierType.email,
      firstName: 'Ada',
      biometricType: BiometricPresentation.faceId,
    );

    final json = profile.toJson();
    expect(json.keys.toSet(), {
      'schemaVersion',
      'userId',
      'identifier',
      'identifierType',
      'firstName',
      'biometricType',
    });
    expect(
      json.keys.any(
        (key) =>
            key.toLowerCase().contains('password') ||
            key.toLowerCase().contains('token'),
      ),
      isFalse,
    );
    final restored = RememberedBiometricProfile.fromJson(json);
    expect(restored, profile);
    expect(restored.firstName, 'Ada');
    expect(restored.isValid, isTrue);
  });

  test('remembered profile normalizes identifier and trims first name', () {
    final email = RememberedBiometricProfile.fromJson(
      _json(
        identifier: '  Ada@Example.COM ',
        firstName: '  Ada  ',
        userId: ' user-1 ',
      ),
    );
    expect(email.identifier, 'ada@example.com');
    expect(email.firstName, 'Ada');
    expect(email.userId, 'user-1');

    final phone = RememberedBiometricProfile.fromJson(
      _json(
        identifier: '0803 123 4567',
        identifierType: 'phone_number',
        biometricType: 'fingerprint',
      ),
    );
    expect(phone.identifier, '+2348031234567');
    expect(phone.identifierType, IdentifierType.phoneNumber);
    expect(phone.biometricType, BiometricPresentation.fingerprint);
    expect(phone.isValid, isTrue);
  });

  test('remembered profile rejects unknown schema and biometric type', () {
    expect(
      () => RememberedBiometricProfile.fromJson(_json(schemaVersion: 2)),
      throwsFormatException,
    );
    expect(
      () => RememberedBiometricProfile.fromJson(_json(schemaVersion: null)),
      throwsFormatException,
    );
    expect(
      () => RememberedBiometricProfile.fromJson(_json(biometricType: 'iris')),
      throwsFormatException,
    );
    expect(
      () =>
          RememberedBiometricProfile.fromJson(_json(identifierType: 'unknown')),
      throwsFormatException,
    );
  });

  test(
    'remembered profile rejects empty user id name and invalid identifier',
    () {
      expect(
        () => RememberedBiometricProfile.fromJson(_json(userId: '  ')),
        throwsFormatException,
      );
      expect(
        () => RememberedBiometricProfile.fromJson(_json(firstName: '')),
        throwsFormatException,
      );
      expect(
        () => RememberedBiometricProfile.fromJson(_json(userId: 7)),
        throwsFormatException,
      );
      expect(
        () => RememberedBiometricProfile.fromJson(
          _json(identifier: 'not-an-email@'),
        ),
        throwsFormatException,
      );
      expect(
        () => RememberedBiometricProfile.fromJson(
          _json(identifier: 'ada@example.com', identifierType: 'phone_number'),
        ),
        throwsFormatException,
      );
      const invalid = RememberedBiometricProfile(
        userId: 'user-1',
        identifier: '12345',
        identifierType: IdentifierType.phoneNumber,
        firstName: 'Ada',
        biometricType: BiometricPresentation.touchId,
      );
      expect(invalid.isValid, isFalse);
    },
  );
}
