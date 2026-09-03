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
/// The amount is grouped and prefixed by pure string manipulation so the
/// server's exact precision is preserved. It is deliberately never parsed to
/// `double` — binary floating point cannot represent decimal money exactly,
/// and the client must not restate a balance the API did not send.
///
/// Returns null when [amount] is absent or is not a plain decimal number, so
/// callers render an explicit unavailable state instead of a wrong figure.
String? formatApiAmount(String? amount, {String? currency}) {
  final raw = amount?.trim();
  if (raw == null || raw.isEmpty) return null;

  final match = RegExp(r'^(-?)(\d+)(?:\.(\d+))?$').firstMatch(raw);
  if (match == null) return null;

  final sign = match.group(1)!;
  final whole = match.group(2)!;
  final fraction = match.group(3);

  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }

  final symbol = _currencySymbols[currency?.toUpperCase()] ?? '';
  final suffix = symbol.isEmpty && currency != null && currency.isNotEmpty
      ? ' $currency'
      : '';
  return '$sign$symbol$grouped${fraction == null ? '' : '.$fraction'}$suffix';
}

/// Masks all but the last [visible] characters of an identifier.
String maskTrailing(String value, {int visible = 4, int groupSize = 4}) {
  final trimmed = value.trim();
  if (trimmed.length <= visible) return trimmed;
  final hiddenCount = trimmed.length - visible;
  final buffer = StringBuffer();
  for (var i = 0; i < hiddenCount; i++) {
    if (i > 0 && i % groupSize == 0) buffer.write(' ');
    buffer.write('•');
  }
  return '$buffer ${trimmed.substring(hiddenCount)}';
}
