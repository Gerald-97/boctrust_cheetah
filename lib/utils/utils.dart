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
