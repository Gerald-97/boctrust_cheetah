import '../module/onboarding/model/auth_enums.dart';

String normalizeEmailAddress(String value) => value.trim().toLowerCase();

String normalizeNigerianPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('0')) {
    return '+234${digits.substring(1)}';
  }
  if (digits.length == 13 && digits.startsWith('234')) return '+$digits';
  return value.trim();
}

IdentifierType identifierTypeFor(String value) =>
    value.contains('@') ? IdentifierType.email : IdentifierType.phoneNumber;

String normalizeIdentifier(String value) =>
    identifierTypeFor(value) == IdentifierType.email
    ? normalizeEmailAddress(value)
    : normalizeNigerianPhone(value);

bool isValidEmailIdentifier(String value) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

bool isValidPhoneIdentifier(String value) =>
    RegExp(r'^\+234\d{10}$').hasMatch(value);

bool isValidIdentifier(String value, IdentifierType type) => switch (type) {
  IdentifierType.email => isValidEmailIdentifier(value),
  IdentifierType.phoneNumber => isValidPhoneIdentifier(value),
  IdentifierType.unknown => false,
};

bool isValidOtpCode(String value) => RegExp(r'^\d{6}$').hasMatch(value);

bool isValidTransactionPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

bool isValidApiPassword(String value) =>
    value.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(value) &&
    RegExp(r'\d').hasMatch(value) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(value);
