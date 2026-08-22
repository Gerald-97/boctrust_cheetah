import 'auth_input.dart' as auth_input;
import 'utils.dart';

bool isEmail(String? value) =>
    value != null &&
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());

String? requiredText(
  String? value, {
  String message = 'Please fill this field',
}) {
  return value == null || value.trim().isEmpty ? message : null;
}

String? optionalName(
  String? value, {
  String message = 'Please input a valid name',
}) {
  if (value == null || value.trim().isEmpty) return null;
  return value.trim().length < 2 ? message : null;
}

String? email(String? value, {String message = 'Input a valid email'}) =>
    isEmail(value) ? null : message;

String? nigerianPhone(String? value) {
  final normalized = normalizePhoneNumber(value ?? '');
  if (normalized.length != 11) return 'Input a valid phone number';
  if (!normalized.startsWith('0')) return "Phone number must start with '0'";
  return null;
}

bool isPasswordValidValue(String? value) {
  if (value == null) return false;
  return auth_input.isValidApiPassword(value);
}

String? isPasswordValid(String? value) => isPasswordValidValue(value)
    ? null
    : 'Use at least 8 characters with a letter, number, and special character';

String? confirmPassword(String? value, String password) =>
    value == password ? null : 'Passwords do not match';

String? fixedDigits(String? value, int length, String message) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  return digits.length == length ? null : message;
}

String? otp(String? value, {int length = 6}) =>
    fixedDigits(value, length, 'Input a valid OTP');
String? transactionPin(String? value, {int length = 4}) =>
    fixedDigits(value, length, 'Input a valid transaction PIN');
String? strongTransactionPin(String? value) {
  final pin = value ?? '';
  if (!auth_input.isValidTransactionPin(pin)) {
    return 'Input a valid transaction PIN';
  }
  if (auth_input.isRepeatedTransactionPin(pin)) {
    return 'Avoid using the same digit four times';
  }
  if (auth_input.isSequentialTransactionPin(pin)) {
    return 'Avoid sequential PINs like 1234 or 4321';
  }
  return null;
}

String? bvn(String? value) => fixedDigits(value, 11, 'Input a valid BVN');
String? nin(String? value) => fixedDigits(value, 11, 'Input a valid NIN');
String? bankAccountNumber(String? value) =>
    fixedDigits(value, 10, 'Input a valid account number');

String? nairaAmountRange(String? value, {num min = 1, num? max}) {
  final parsed = num.tryParse(stripAmountFormatting(value ?? ''));
  if (parsed == null) return 'Please input an amount';
  if (parsed < min) {
    return 'Please input an amount greater than ${formatNaira(min)}';
  }
  if (max != null && parsed > max) {
    return 'Please input an amount less than ${formatNaira(max)}';
  }
  return null;
}

String? requiredPicker<T>(
  T? value, {
  String message = 'Please select an option',
}) => value == null ? message : null;

String? conditionalOtherText(
  String? value, {
  required bool isOther,
  String message = 'Please fill this field',
}) {
  if (!isOther) return null;
  return requiredText(value, message: message);
}

String? billCustomerReference(String? value) =>
    requiredText(value, message: 'Please input a valid customer reference');
String? merchantCode(String? value) =>
    requiredText(value, message: 'Please input a valid merchant code');
String? fileUploadRequired(Object? value) =>
    value == null ? 'Please upload a required file' : null;
