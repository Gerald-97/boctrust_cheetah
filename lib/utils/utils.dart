import 'package:intl/intl.dart';

final NumberFormat _nairaFormatter = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 2,
);
final NumberFormat _compactNairaFormatter = NumberFormat.currency(
  locale: 'en_NG',
  symbol: '₦',
  decimalDigits: 0,
);

String formatNaira(num amount, {bool decimal = true}) =>
    (decimal ? _nairaFormatter : _compactNairaFormatter).format(amount);

String normalizePhoneNumber(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return digits;
  return digits.startsWith('0') ? digits : '0$digits';
}

String formatPhoneWithDashes(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 4 || i == 7) buffer.write('-');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String notificationDateGroup(DateTime date, {DateTime? now}) {
  final today = DateTime(
    now?.year ?? DateTime.now().year,
    now?.month ?? DateTime.now().month,
    now?.day ?? DateTime.now().day,
  );
  final target = DateTime(date.year, date.month, date.day);
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference <= 7) return 'Earlier this week';
  return DateFormat('MMMM d, y').format(date);
}

String stripAmountFormatting(String value) =>
    value.replaceAll(',', '').replaceAll('₦', '').trim();

const _currencySymbols = <String, String>{'NGN': '₦'};

/// Formats an API-authoritative decimal amount string for display.
///
/// Amounts always show two decimal places (kobo), rounded half-up from the
/// server's precision: `2500.0000` → `₦2,500.00`, `9.995` → `₦10.00`. The
/// rounding is done on the decimal digits themselves; the amount is
/// deliberately never parsed to `double`, because binary floating point
/// cannot represent decimal money exactly.
///
/// Returns null when [amount] is absent or is not a plain decimal number, so
/// callers render an explicit unavailable state instead of a wrong figure.
String? formatApiAmount(String? amount, {String? currency}) {
  final raw = amount?.trim();
  if (raw == null || raw.isEmpty) return null;

  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(raw);
  if (match == null) return null;

  final sign = match.group(1)!;
  final (whole, fraction) = _roundToKobo(match.group(2)!, match.group(3) ?? '');

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }

  final symbol = _currencySymbols[currency?.toUpperCase()] ?? '';
  final suffix = symbol.isEmpty && currency != null && currency.isNotEmpty
      ? ' $currency'
      : '';
  final signed = sign.isNotEmpty && '$whole$fraction'.contains(RegExp('[1-9]'))
      ? sign
      : '';
  return '$signed$symbol$grouped.$fraction$suffix';
}

/// Rounds a decimal given as digit strings to two places, half-up, without
/// floating point. Returns the whole part (no leading zeros) and exactly two
/// fraction digits.
(String, String) _roundToKobo(String whole, String fraction) {
  final padded = fraction.padRight(3, '0');
  var cents = BigInt.parse('$whole${padded.substring(0, 2)}');
  if (padded.codeUnitAt(2) >= 0x35) cents += BigInt.one; // third digit ≥ 5
  final digits = cents.toString().padLeft(3, '0');
  return (
    digits.substring(0, digits.length - 2),
    digits.substring(digits.length - 2),
  );
}
