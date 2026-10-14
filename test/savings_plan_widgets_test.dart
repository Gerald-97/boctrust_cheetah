import 'package:boctrust_savings_loan/module/savings/screens/savings_plan_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progress is only for a usable target', () {
    expect(savingsPlanProgress(principal: '2500.00', target: '5000.00'), (
      fraction: 0.5,
      reached: false,
    ));
    expect(savingsPlanProgress(principal: '5000.00', target: '4500.00'), (
      fraction: 1.0,
      reached: true,
    ));
    expect(savingsPlanProgress(principal: '5000.00', target: '0.00'), isNull);
    expect(savingsPlanProgress(principal: null, target: '4500.00'), isNull);
  });
}
