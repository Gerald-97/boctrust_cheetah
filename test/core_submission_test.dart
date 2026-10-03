import 'dart:async';

import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_submission_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ServiceResponse<CoreTransferAck> _error(int? status, [String message = 'x']) =>
    ServiceResponse.error(message, statusCode: status);

void main() {
  test('responses map to accepted, rejected or unknown', () {
    final accepted = mapCoreSubmission(
      const ServiceResponse.success(
        CoreTransferAck(responseCode: '00', reference: 'ref-1'),
        statusCode: 200,
      ),
    );
    expect(accepted, isA<AcceptedSubmission>());
    expect((accepted as AcceptedSubmission).ack.reference, 'ref-1');

    CoreRejection? reason(ServiceResponse<CoreTransferAck> r) =>
        switch (mapCoreSubmission(r)) {
          RejectedSubmission(:final reason) => reason,
          _ => null,
        };
    expect(reason(_error(403)), CoreRejection.accountRestricted);
    expect(reason(_error(404)), CoreRejection.accountMissing);
    expect(reason(_error(409)), CoreRejection.referenceCollision);
    expect(
      reason(_error(400, 'Insufficient balance')),
      CoreRejection.insufficientFunds,
    );

    // No answer, a server fault, or an unreadable success: never success.
    for (final unknown in [
      _error(null),
      _error(502),
      _error(500),
      _error(200),
    ]) {
      expect(mapCoreSubmission(unknown), isA<UnknownSubmission>());
    }
  });

  test(
    'one draft is sent once and an unknown outcome is never resent',
    () async {
      final service = _Service();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(_provider(service).notifier);

      final first = notifier.submit('draft-a');
      final second = notifier.submit('draft-a');
      service.reply.complete(_error(null));
      await Future.wait([first, second]);
      expect(service.calls, 1);
      expect(
        container.read(_provider(service)).outcome,
        isA<UnknownSubmission>(),
      );

      service.reply = Completer();
      await notifier.submit('draft-a');
      expect(service.calls, 1);
    },
  );
}

class _Service {
  var calls = 0;
  Completer<ServiceResponse<CoreTransferAck>> reply = Completer();
  Future<ServiceResponse<CoreTransferAck>> send(String draft) {
    calls++;
    return reply.future;
  }
}

final _providers =
    <_Service, NotifierProvider<_Notifier, CoreSubmissionState<String>>>{};

NotifierProvider<_Notifier, CoreSubmissionState<String>> _provider(
  _Service service,
) => _providers.putIfAbsent(
  service,
  () => NotifierProvider(() => _Notifier(service)),
);

class _Notifier extends CoreSubmissionNotifier<String> {
  _Notifier(this.service);
  final _Service service;

  @override
  Future<ServiceResponse<CoreTransferAck>> send(String draft) =>
      service.send(draft);
}
