import 'package:equatable/equatable.dart';

import '../../../utils/auth_input.dart';
import 'auth_enums.dart';

/// The biometric the device actually has enrolled, which decides whether the
/// UI says Face ID, Touch ID, or fingerprint.
enum BiometricPresentation {
  faceId('face_id'),
  touchId('touch_id'),
  fingerprint('fingerprint');

  const BiometricPresentation(this.wireValue);
  final String wireValue;

  static BiometricPresentation? fromWire(Object? value) {
    for (final presentation in values) {
      if (presentation.wireValue == value) return presentation;
    }
    return null;
  }
}

/// Non-secret data for the one account remembered for biometric login.
///
/// Holds only what identifies the account and renders the personalized login
/// page; never a password, token, or full profile.
class RememberedBiometricProfile extends Equatable {
  const RememberedBiometricProfile({
    this.schemaVersion = currentSchemaVersion,
    required this.userId,
    required this.identifier,
    required this.identifierType,
    required this.firstName,
    required this.biometricType,
  });

  static const currentSchemaVersion = 1;

  /// Throws [FormatException] for any malformed, unsupported, or inconsistent
  /// value rather than accepting it.
  factory RememberedBiometricProfile.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != currentSchemaVersion) {
      throw const FormatException('Unsupported biometric profile schema.');
    }
    final userId = _string(json['userId']).trim();
    final firstName = _string(json['firstName']).trim();
    final identifierType = IdentifierType.fromWire(json['identifierType']);
    final biometricType = BiometricPresentation.fromWire(json['biometricType']);
    if (biometricType == null) {
      throw const FormatException('Unsupported biometric type.');
    }
    final profile = RememberedBiometricProfile(
      userId: userId,
      identifier: normalizeIdentifier(_string(json['identifier'])),
      identifierType: identifierType,
      firstName: firstName,
      biometricType: biometricType,
    );
    if (!profile.isValid) {
      throw const FormatException('Invalid biometric profile.');
    }
    return profile;
  }

  final int schemaVersion;
  final String userId;
  final String identifier;
  final IdentifierType identifierType;
  final String firstName;
  final BiometricPresentation biometricType;

  bool get isValid =>
      schemaVersion == currentSchemaVersion &&
      userId.trim().isNotEmpty &&
      firstName.trim().isNotEmpty &&
      identifierType != IdentifierType.unknown &&
      identifierTypeFor(identifier) == identifierType &&
      isValidIdentifier(identifier, identifierType);

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'userId': userId,
    'identifier': identifier,
    'identifierType': identifierType.wireValue,
    'firstName': firstName,
    'biometricType': biometricType.wireValue,
  };

  static String _string(Object? value) {
    if (value is! String) {
      throw const FormatException('Invalid biometric profile field.');
    }
    return value;
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    userId,
    identifier,
    identifierType,
    firstName,
    biometricType,
  ];
}
