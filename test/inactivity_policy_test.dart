import 'package:boctrust_savings_loan/app/inactivity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('warns at 2:00 and expires at 3:00 without activity', () {
    final last = DateTime.utc(2026, 10, 15, 9);
    InactivityStatus after(int seconds) =>
        InactivityPolicy.evaluate(last, last.add(Duration(seconds: seconds)));

    expect(after(119), InactivityStatus.active);
    expect(after(120), InactivityStatus.warning);
    expect(after(180), InactivityStatus.expired);
  });

  test('a clock moved backward beyond the skew tolerance expires', () {
    final last = DateTime.utc(2026, 10, 15, 9);

    expect(
      InactivityPolicy.evaluate(last, last.subtract(const Duration(hours: 1))),
      InactivityStatus.expired,
    );
  });
}
