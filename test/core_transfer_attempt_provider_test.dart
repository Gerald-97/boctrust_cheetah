import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/intrabank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_transfer_attempt_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

const _draft = BoctrustTransferDraft(
  toAccountNumber: '1100037777',
  amountKobo: '1000',
);

ServiceResponse<CoreTransferAck> _error(int status) =>
    ServiceResponse.error('x', statusCode: status);

ProviderContainer _setUp({bool ready = true}) {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      transferAuthorizationReadyProvider.overrideWithValue(ready),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('cancel frees the reservation', () {
    final notifier = _setUp().read(coreTransferAttemptProvider.notifier);

    notifier.cancelReview(notifier.beginReview(_draft)!);

    expect(notifier.beginReview(_draft), isNotNull);
  });

  test('no attempt starts while authorization is not ready', () {
    final notifier = _setUp(
      ready: false,
    ).read(coreTransferAttemptProvider.notifier);

    expect(notifier.beginReview(_draft), isNull);
  });

  test('the documented transfer errors map per the Core docs', () {
    CoreSubmissionOutcome map(
      ServiceResponse<CoreTransferAck> r, {
      bool interbank = false,
    }) => mapCoreTransferSubmission(r, interbank: interbank);

    expect(map(_error(401)), const RejectedSubmission(CoreRejection.wrongPin));
    expect(
      map(_error(403)),
      const RejectedSubmission(CoreRejection.transferRestricted),
    );
    expect(
      map(_error(409)),
      const RejectedSubmission(CoreRejection.possibleDuplicate),
    );
    expect(
      map(_error(500), interbank: true),
      const RejectedSubmission(CoreRejection.recipientUnresolved),
    );
    expect(
      map(
        const ServiceResponse.error(
          'Your session has expired. Please sign in again.',
          statusCode: 401,
          errorCode: kLocalSessionExpiredCode,
        ),
      ),
      const RejectedSubmission(CoreRejection.sessionExpired),
    );
  });
}
