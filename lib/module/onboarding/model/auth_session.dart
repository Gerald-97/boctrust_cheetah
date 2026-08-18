import 'package:equatable/equatable.dart';

import 'auth_enums.dart';

class PersistedSessionMetadata extends Equatable {
  const PersistedSessionMetadata({
    this.schemaVersion = 1,
    required this.expiresAt,
    required this.userId,
    this.email,
    this.phoneNumber,
    required this.identifierType,
  });

  factory PersistedSessionMetadata.fromJson(Map<String, Object?> json) {
    final expiresAt = DateTime.parse(json['expiresAt']! as String).toUtc();
    return PersistedSessionMetadata(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      expiresAt: expiresAt,
      userId: json['userId']! as String,
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      identifierType: IdentifierType.fromWire(json['identifierType']),
    );
  }

  final int schemaVersion;
  final DateTime expiresAt;
  final String userId;
  final String? email;
  final String? phoneNumber;
  final IdentifierType identifierType;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'userId': userId,
    'email': email,
    'phoneNumber': phoneNumber,
    'identifierType': identifierType.wireValue,
  };

  bool get isValid =>
      schemaVersion == 1 &&
      userId.trim().isNotEmpty &&
      identifierType != IdentifierType.unknown &&
      expiresAt.isAfter(DateTime.now().toUtc());

  @override
  List<Object?> get props => [
    schemaVersion,
    expiresAt,
    userId,
    email,
    phoneNumber,
    identifierType,
  ];
}

class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.userId,
    this.email,
    this.phoneNumber,
    required this.identifierType,
  });

  final String accessToken;
  final DateTime expiresAt;
  final String userId;
  final String? email;
  final String? phoneNumber;
  final IdentifierType identifierType;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  PersistedSessionMetadata get metadata => PersistedSessionMetadata(
    expiresAt: expiresAt,
    userId: userId,
    email: email,
    phoneNumber: phoneNumber,
    identifierType: identifierType,
  );

  @override
  List<Object?> get props => [
    accessToken,
    expiresAt,
    userId,
    email,
    phoneNumber,
    identifierType,
  ];
}
