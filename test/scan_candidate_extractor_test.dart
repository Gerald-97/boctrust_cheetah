import 'package:boctrust_savings_loan/module/core_banking/model/scan_text_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/scan_candidate_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

RecognizedLine _line(String text, {double top = 0, double left = 0}) =>
    RecognizedLine(
      text,
      ScanTextBox(left: left, top: top, width: 0.2, height: 0.05),
    );

List<String> _accounts(List<RecognizedLine> lines) =>
    extractScanCandidates(lines).accountNumbers;

void main() {
  test(
    'digit groups split by spaces or hyphens join, keeping leading zero',
    () {
      expect(_accounts([_line('Acct: 0123 456-789')]), ['0123456789']);
    },
  );

  test('runs longer than ten digits give no candidate', () {
    expect(_accounts([_line('08012345678'), _line('2340123456789')]), isEmpty);
  });

  test('numbers are ordered by position and deduplicated', () {
    final lines = [
      _line('2222222222', top: 0.5),
      _line('1111111111', top: 0.1),
      _line('2222222222', top: 0.9),
    ];
    expect(_accounts(lines), ['1111111111', '2222222222']);
  });

  test('look-alike letters read as digits only inside a digit token', () {
    expect(_accounts([_line('O123456789')]), ['0123456789']);
    expect(_accounts([_line('ABC1234567')]), isEmpty);
  });

  test('bank text keeps every line with its digits removed', () {
    final result = extractScanCandidates([
      _line('Moniepoint'),
      _line('0123456789 Access Bank'),
    ]);
    expect(result.bankTextLines, ['Moniepoint', 'Access Bank']);
  });
}
