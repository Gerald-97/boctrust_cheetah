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
    RegExp(r'^\+234[789][01]\d{8}$').hasMatch(value);

bool isValidNigerianPhone(String value) =>
    isValidPhoneIdentifier(normalizeNigerianPhone(value));

bool isValidIdentifier(String value, IdentifierType type) => switch (type) {
  IdentifierType.email => isValidEmailIdentifier(value),
  IdentifierType.phoneNumber => isValidPhoneIdentifier(value),
  IdentifierType.unknown => false,
};

bool isValidOtpCode(String value) => RegExp(r'^\d{6}$').hasMatch(value);

bool isValidTransactionPin(String value) => RegExp(r'^\d{4}$').hasMatch(value);

bool hasPasswordMinLength(String value) => value.length >= 8;

bool hasPasswordLetter(String value) => RegExp(r'[A-Za-z]').hasMatch(value);

bool hasPasswordDigit(String value) => RegExp(r'\d').hasMatch(value);

bool hasPasswordSymbol(String value) => RegExp(r'[^A-Za-z0-9]').hasMatch(value);

int passwordCriteriaMet(String value) => [
  hasPasswordMinLength(value),
  hasPasswordLetter(value),
  hasPasswordDigit(value),
  hasPasswordSymbol(value),
].where((met) => met).length;

bool isValidApiPassword(String value) =>
    hasPasswordMinLength(value) &&
    hasPasswordLetter(value) &&
    hasPasswordDigit(value) &&
    hasPasswordSymbol(value);

bool isRepeatedTransactionPin(String value) =>
    isValidTransactionPin(value) && value.split('').toSet().length == 1;

bool isSequentialTransactionPin(String value) {
  if (!isValidTransactionPin(value)) return false;
  final digits = value.split('').map(int.parse).toList(growable: false);
  final ascending = List.generate(
    digits.length - 1,
    (index) => digits[index + 1] - digits[index],
  ).every((difference) => difference == 1);
  final descending = List.generate(
    digits.length - 1,
    (index) => digits[index] - digits[index + 1],
  ).every((difference) => difference == 1);
  return ascending || descending;
}

bool isStrongTransactionPin(String value) =>
    isValidTransactionPin(value) &&
    !isRepeatedTransactionPin(value) &&
    !isSequentialTransactionPin(value);
