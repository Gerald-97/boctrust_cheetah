import 'package:boctrust_savings_loan/module/core_banking/model/core_money.dart';
import 'package:flutter_test/flutter_test.dart';

String? _kobo(String text) =>
    switch (parseNairaToKobo(text, maxKobo: '100000000')) {
      ValidMoney(:final minorUnits) => minorUnits,
      InvalidMoney() => null,
    };

void main() {
  test('Naira text becomes exact Kobo or is rejected', () {
    expect(_kobo('1'), '100');
    expect(_kobo('1.2'), '120');
    expect(_kobo('1.23'), '123');
    expect(_kobo('₦1,000.50'), '100050');
    for (final bad in ['', 'abc', '0', '000', '-5', '1e3', '12.345']) {
      expect(_kobo(bad), isNull, reason: bad);
    }
    // Above the limit, including far beyond int64.
    expect(_kobo('1000001'), isNull);
    expect(_kobo('99999999999999999999'), isNull);
  });
}
