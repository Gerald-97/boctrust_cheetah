import 'package:boctrust_savings_loan/utils/input_formatters.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _type(String text) => ThousandsAmountFormatter()
    .formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    )
    .text;

void main() {
  test('groups thousands and keeps up to two decimals', () {
    expect(_type('1000'), '1,000');
    expect(_type('25000000.5'), '25,000,000.5');
    expect(_type('1234.567'), '1,234.56');
    expect(_type('1,0a00.'), '1,000.');
    expect(_type('.5'), '0.5');
    expect(_type('100'), '100');
  });

  test('keeps the cursor beside the digit it followed', () {
    final value = ThousandsAmountFormatter().formatEditUpdate(
      const TextEditingValue(text: '1,000'),
      const TextEditingValue(
        text: '19,000',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );

    expect(value.text, '19,000');
    expect(value.selection.baseOffset, 2);
  });
}
