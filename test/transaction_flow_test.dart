import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/send/model/transaction_models.dart';
import 'package:boctrust_savings_loan/module/send/provider/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

class RejectedTransfer extends TransferSubmissionNotifier {
  @override
  Future<void> submit(TransferRequest request) async =>
      state = const NotifierState.error('The receiving bank declined this.');
}

/// Finds a field by its label, independent of how the label is displayed.
Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is AppTextField && widget.label == label,
);

void main() {
  testWidgets('a failed transfer never shows success or a reference', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      route: AppRoutes.sendOtherBank,
      overrides: [
        featureAvailabilityProvider(
          FeatureCapability.transfers,
        ).overrideWithValue(FeatureAvailability.available),
        transferSubmissionProvider.overrideWith(RejectedTransfer.new),
      ],
    );

    await tester.enterText(_field('Account number'), '0123456789');
    await tester.enterText(_field('Bank name'), 'Example Bank');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('Amount'), '5000');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byType(EditableText).last, '1357');
    await tester.pump();
    await tester.tap(find.widgetWithText(PrimaryButton, 'Send money'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Transfer failed'), findsOneWidget);
    expect(find.text('Successful'), findsNothing);
    expect(find.byType(BocReceiptCard), findsNothing);
    expect(find.textContaining('Reference'), findsNothing);
  });
}
