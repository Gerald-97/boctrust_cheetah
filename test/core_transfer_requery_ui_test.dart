import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/core_transfer_attempt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

Future<void> _show(WidgetTester tester, CoreTransferAttempt attempt) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: await flowTestOverrides(),
      child: MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: CoreTransferAttemptView(
              attempt: attempt,
              onExit: () {},
              onEditDetails: () {},
              onStartDifferent: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

CoreTransferAttempt _settled(
  CoreSubmissionOutcome outcome, {
  CoreLiveTransferStatus? live,
  String? checkError,
}) => CoreTransferAttempt(
  id: 1,
  draft: const BoctrustTransferDraft(
    toAccountNumber: '1100037777',
    amountKobo: '1000',
  ),
  phase: CoreTransferPhase.settled,
  outcome: outcome,
  live: live,
  checkError: checkError,
);

void main() {
  testWidgets('a bank decline shows its reason and that nothing moved', (
    tester,
  ) async {
    await _show(
      tester,
      _settled(
        const RejectedSubmission(
          CoreRejection.bankDeclined,
          detail: 'Beneficiary account is dormant',
        ),
      ),
    );

    expect(find.text('Transfer declined'), findsOneWidget);
    expect(
      find.textContaining('Beneficiary account is dormant'),
      findsOneWidget,
    );
    expect(find.textContaining('No money has left'), findsOneWidget);
  });

  testWidgets('an unknown outcome never claims nothing moved', (tester) async {
    await _show(tester, _settled(const UnknownSubmission()));

    expect(find.text('Transfer not confirmed'), findsOneWidget);
    expect(find.textContaining('No money has left'), findsNothing);
  });

  testWidgets('a failed later check keeps the confirmed result', (
    tester,
  ) async {
    await _show(
      tester,
      _settled(
        const AcceptedSubmission(
          CoreTransferAck(
            responseCode: '00',
            retrievalReference: 'a1b2c3d4e5f6',
          ),
        ),
        live: const CoreLiveTransferStatus(
          state: CoreLiveState.completed,
          trackingReference: CoreTrackingReference(
            CoreTransferKind.intrabank,
            'a1b2c3d4e5f6',
          ),
        ),
        checkError: "We couldn't check this transfer. Try again shortly.",
      ),
    );

    expect(find.text('Transfer successful'), findsOneWidget);
  });
}
