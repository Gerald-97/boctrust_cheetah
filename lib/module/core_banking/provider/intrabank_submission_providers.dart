import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/core_submission_models.dart';
import '../model/intrabank_models.dart';
import '../service/core_transfer_service.dart';
import 'core_submission_notifier.dart';

final ownAccountMoveProvider =
    NotifierProvider<
      OwnAccountMoveNotifier,
      CoreSubmissionState<OwnAccountMoveDraft>
    >(OwnAccountMoveNotifier.new);

/// Moves money between the customer's own accounts, once per draft.
class OwnAccountMoveNotifier
    extends CoreSubmissionNotifier<OwnAccountMoveDraft> {
  @override
  Future<ServiceResponse<CoreTransferAck>> send(OwnAccountMoveDraft draft) =>
      ref.read(coreTransferServiceProvider).moveBetweenOwnAccounts(draft);
}
