import 'package:flutter/services.dart';

class PhoneDashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 4 || i == 7) buffer.write('-');
      buffer.write(limited[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

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
