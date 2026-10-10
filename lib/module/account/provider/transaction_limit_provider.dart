import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/transaction_limit_models.dart';
import '../service/core_transaction_limit_service.dart';

/// The customer's limits. Re-read when the session changes and dropped when
/// no screen shows them.
final transactionLimitsProvider =
    FutureProvider.autoDispose<NotifierState<TransactionLimits>>((ref) {
      ref.watch(authSessionProvider);
      return ref.read(coreTransactionLimitServiceProvider).getLimits();
    });
