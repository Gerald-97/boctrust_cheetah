import 'package:flutter/services.dart';

/// Bank account entry accepts digits only and never more than ten digits.
List<TextInputFormatter> bankAccountNumberInputFormatters() => [
  FilteringTextInputFormatter.digitsOnly,
  LengthLimitingTextInputFormatter(10),
];

/// Formats local and +234 phone numbers while rejecting invalid pasted text.
class NigerianPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final text = raw.trim();
    if (!RegExp(r'^\+?[0-9\s-]*$').hasMatch(text)) return oldValue;
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final limit = digits.startsWith('0') ? 11 : 13;
    if (digits.length > limit) return oldValue;

    final international = text.startsWith('+') || digits.startsWith('234');
    final breaks = international ? const {3, 6, 9} : const {4, 7};
    final formatted = StringBuffer(text.startsWith('+') ? '+' : '');
    for (var i = 0; i < digits.length; i++) {
      if (breaks.contains(i)) formatted.write('-');
      formatted.write(digits[i]);
    }
    final result = formatted.toString();

    int mapOffset(int rawOffset) {
      if (rawOffset < 0) return result.length;
      final before = raw.substring(0, rawOffset.clamp(0, raw.length));
      final digitsBefore = before.replaceAll(RegExp(r'\D'), '').length;
      var offset = before.contains('+') && result.startsWith('+') ? 1 : 0;
      var seen = 0;
      while (offset < result.length && seen < digitsBefore) {
        if (RegExp(r'\d').hasMatch(result[offset])) seen++;
        offset++;
      }
      return offset;
    }

    return TextEditingValue(
      text: result,
      selection: TextSelection(
        baseOffset: mapOffset(newValue.selection.baseOffset),
        extentOffset: mapOffset(newValue.selection.extentOffset),
      ),
    );
  }
}

class PhoneDashFormatter extends NigerianPhoneInputFormatter {}

/// Naira amounts as typed: thousands grouped with commas, one decimal point
/// and at most two decimals. The cursor stays beside the digit it followed.
/// Amount parsers already ignore the commas.
class ThousandsAmountFormatter extends TextInputFormatter {
  static bool _kept(String c) => c == '.' || RegExp(r'\d').hasMatch(c);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final cursor = newValue.selection.baseOffset.clamp(0, raw.length);
    final kept = raw.split('').where(_kept).join();
    final keptBeforeCursor = raw
        .substring(0, cursor)
        .split('')
        .where(_kept)
        .length;

    final dot = kept.indexOf('.');
    var whole = dot < 0 ? kept : kept.substring(0, dot);
    final fraction = dot < 0
        ? null
        : kept.substring(dot + 1).replaceAll('.', '');
    if (whole.isEmpty && fraction != null) whole = '0';
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    final text = fraction == null
        ? grouped
        : '$grouped.${fraction.length > 2 ? fraction.substring(0, 2) : fraction}';

    var offset = 0;
    for (
      var seen = 0;
      offset < text.length && seen < keptBeforeCursor;
      offset++
    ) {
      if (text[offset] != ',') seen++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
