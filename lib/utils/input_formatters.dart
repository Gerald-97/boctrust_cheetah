import 'package:flutter/services.dart';

class CardMonthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var newText = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 2 == 0 && nonZeroIndex != newText.length) {
        buffer.write('/');
      }
    }

    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class NumberInputFormatter extends TextInputFormatter {
  NumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      int nonZeroIndex = i + 1;
      int p1 = 4, p2 = 7;

      if ((nonZeroIndex == p1 || nonZeroIndex == p2) &&
          nonZeroIndex != text.length) {
        buffer.write('-'); // Add space.
      }
    }

    var res = buffer.toString();
    return newValue.copyWith(
      text: res,
      selection: TextSelection.collapsed(offset: res.length),
    );
  }
}

class AccountNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      int nonZeroIndex = i + 1;

      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' '); // Add space.
      }
    }

    var res = buffer.toString();
    return newValue.copyWith(
      text: res,
      selection: TextSelection.collapsed(offset: res.length),
    );
  }
}

class NameInputFormatter extends TextInputFormatter {
  static final _allowedPattern = RegExp(r'[^a-zA-Z\s]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains(_allowedPattern)) {
      return newValue;
    }

    final filtered = newValue.text.replaceAll(_allowedPattern, '');
    final selectionOffset =
        newValue.selection.baseOffset -
        (newValue.text.length - filtered.length);

    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, filtered.length),
      ),
    );
  }
}

/// Allows letters, digits, spaces, and address-specific punctuation:
/// comma (,), hyphen (-), apostrophe ('), period (.), forward slash (/),
/// hash (#), and ampersand (&).
class AddressInputFormatter extends TextInputFormatter {
  static final _allowedPattern = RegExp(r"[^a-zA-Z0-9\s,\-'.]");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.text.contains(_allowedPattern)) {
      return newValue;
    }

    final filtered = newValue.text.replaceAll(_allowedPattern, '');
    final selectionOffset =
        newValue.selection.baseOffset -
        (newValue.text.length - filtered.length);

    return newValue.copyWith(
      text: filtered,
      selection: TextSelection.collapsed(
        offset: selectionOffset.clamp(0, filtered.length),
      ),
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  static const separator = ','; // Change this to '.' for other locales

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Short-circuit if the new value is empty
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Handle "deletion" of separator character
    String oldValueText = oldValue.text
        .split(".")
        .first
        .replaceAll(separator, '');
    String newValueText = newValue.text
        .split(".")
        .first
        .replaceAll(separator, '');

    if (oldValue.text.endsWith(separator) &&
        oldValue.text.length == newValue.text.length + 1) {
      newValueText = newValueText.substring(0, newValueText.length - 1);
    }

    // Only process if the old value and new value are different
    if (oldValueText != newValueText) {
      int selectionIndex =
          newValue.text.length - newValue.selection.extentOffset;
      final chars = newValueText.split('');

      String newString = '';
      for (int i = chars.length - 1; i >= 0; i--) {
        if ((chars.length - 1 - i) % 3 == 0 && i != chars.length - 1) {
          newString = separator + newString;
        }
        newString = chars[i] + newString;
      }

      return TextEditingValue(
        text: newString.toString(),
        selection: TextSelection.collapsed(
          offset: newString.length - selectionIndex,
        ),
      );
    }

    // If the new value and old value are the same, just return as-is
    return newValue;
  }
}

class DigitsOnlyFormatter extends FilteringTextInputFormatter {
  DigitsOnlyFormatter() : super.allow(RegExp(r'\d'));
}

class MaxLengthDigitsFormatter extends TextInputFormatter {
  MaxLengthDigitsFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final truncated = digits.length > maxLength
        ? digits.substring(0, maxLength)
        : digits;
    return TextEditingValue(
      text: truncated,
      selection: TextSelection.collapsed(offset: truncated.length),
    );
  }
}

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

class NairaThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final reversed = digits.split('').reversed.toList();
    final chunks = <String>[];
    for (var i = 0; i < reversed.length; i += 3) {
      chunks.add(reversed.skip(i).take(3).toList().reversed.join());
    }
    final text = chunks.reversed.join(',');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class UppercaseTrimFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.trimLeft().toUpperCase();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

TextInputFormatter otpLengthFormatter([int length = 6]) =>
    MaxLengthDigitsFormatter(length);
TextInputFormatter pinLengthFormatter([int length = 4]) =>
    MaxLengthDigitsFormatter(length);
TextInputFormatter bvnLengthFormatter() => MaxLengthDigitsFormatter(11);
TextInputFormatter ninLengthFormatter() => MaxLengthDigitsFormatter(11);
TextInputFormatter accountNumberLengthFormatter() =>
    MaxLengthDigitsFormatter(10);
