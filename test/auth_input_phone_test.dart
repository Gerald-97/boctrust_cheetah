import 'package:boctrust_savings_loan/utils/auth_input.dart';
import 'package:boctrust_savings_loan/utils/input_formatters.dart';
import 'package:boctrust_savings_loan/utils/validators.dart' as validators;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone normalization accepts dashes and spaces in local numbers', () {
    expect(normalizeNigerianPhone('0800-000-0000'), '+2348000000000');
    expect(normalizeNigerianPhone('0800 000 0000'), '+2348000000000');
    expect(isValidNigerianPhone('0800-000-0000'), isTrue);
  });

  test('phone normalization accepts formatted country-code numbers', () {
    expect(normalizeNigerianPhone('+234-800-000-0000'), '+2348000000000');
    expect(normalizeNigerianPhone('234-800-000-0000'), '+2348000000000');
    expect(isValidNigerianPhone('+234-800-000-0000'), isTrue);
  });

  test('phone normalization does not silently discard letters', () {
    expect(isValidNigerianPhone('0800-a000-0000'), isFalse);
    expect(isValidNigerianPhone('+234-800-000-000x0'), isFalse);
    expect(validators.nigerianPhone('0800-a000-0000'), isNotNull);
  });

  test('phone input accepts dashed local and international numbers', () {
    final formatter = NigerianPhoneInputFormatter();
    for (final value in ['0800-000-0000', '+234-800-000-0000']) {
      final incoming = TextEditingValue(text: value);
      expect(
        formatter.formatEditUpdate(const TextEditingValue(), incoming).text,
        value,
      );
    }
  });

  test('phone input inserts dashes while typing or pasting', () {
    final formatter = NigerianPhoneInputFormatter();
    for (final (raw, formatted) in [
      ('08030', '0803-0'),
      ('08030000000', '0803-000-0000'),
      ('0803 000 0000', '0803-000-0000'),
      ('+2348030000000', '+234-803-000-0000'),
      ('2348030000000', '234-803-000-0000'),
    ]) {
      final incoming = TextEditingValue(
        text: raw,
        selection: TextSelection.collapsed(offset: raw.length),
      );
      expect(
        formatter.formatEditUpdate(const TextEditingValue(), incoming).text,
        formatted,
      );
    }
  });

  test('phone input keeps the cursor with an edited middle digit', () {
    final formatted = NigerianPhoneInputFormatter().formatEditUpdate(
      const TextEditingValue(text: '0803-000-0000'),
      const TextEditingValue(
        text: '08031000000',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    expect(formatted.text, '0803-100-0000');
    expect(formatted.selection.baseOffset, 6);
  });

  test(
    'phone input rejects letters and numbers beyond the supported length',
    () {
      final formatter = NigerianPhoneInputFormatter();
      const previous = TextEditingValue(text: '0800-000-0000');
      expect(
        formatter.formatEditUpdate(
          previous,
          const TextEditingValue(text: '0800-x000-0000'),
        ),
        previous,
      );
      expect(
        formatter.formatEditUpdate(
          previous,
          const TextEditingValue(text: '0800-000-00000'),
        ),
        previous,
      );
    },
  );
}
