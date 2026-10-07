import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_transfer_requery_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/core_banking/screens/core_transfer_attempt_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _tracking = CoreTrackingReference(CoreTransferKind.interbank, 'TX-9');

/// Holds one accepted interbank attempt and answers checks from [replies].
class _Attempts extends CoreTransferAttemptNotifier {
  final replies = <CoreLiveState>[CoreLiveState.reversed];
  var checks = 0;

  @override
  CoreTransferAttemptState build() => const CoreTransferAttemptState(
    current: CoreTransferAttempt(
      id: 1,
      draft: InterbankTransferDraft(
        bankCode: '000014',
        bankName: 'Zenith',
        accountNumber: '0123456789',
        accountName: 'ADA OBI',
        amountKobo: '5000',
      ),
      phase: CoreTransferPhase.settled,
      outcome: AcceptedSubmission(
        CoreTransferAck(status: 'Pending', transactionReference: 'TX-9'),
      ),
    ),
  );

  @override
  Future<void> check(int id) async {
    checks++;
    final current = state.current!;
    state = CoreTransferAttemptState(
      current: current.withLive(
        CoreLiveTransferStatus(
          state: replies.removeAt(0),
          trackingReference: _tracking,
          isReversed: true,
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Check status shows the live outcome', (tester) async {
    final attempts = _Attempts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coreTransferAttemptProvider.overrideWith(() => attempts),
          stagingModeProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: CheetahTheme.lightTheme,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ListView(
                children: [
                  CoreTransferAttemptView(
                    attempt: ref.watch(coreTransferAttemptProvider).current!,
                    onExit: () {},
                    onEditDetails: () {},
                    onStartDifferent: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Transfer processing'), findsOneWidget);

    await tester.tap(find.text('Check status'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(attempts.checks, 1);
    expect(find.text('Transfer reversed'), findsOneWidget);
    expect(find.text('Check status'), findsNothing);
  });
}
