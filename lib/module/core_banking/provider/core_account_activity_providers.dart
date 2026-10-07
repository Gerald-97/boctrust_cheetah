import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/core_account_summary.dart';
import '../service/core_account_service.dart';

/// The live summary of one account. Re-read when the session changes, so a
/// summary never outlives the customer it belongs to, and dropped when no
/// screen shows it.
final coreAccountSummaryProvider = FutureProvider.autoDispose
    .family<NotifierState<CoreAccountSummary>, String>((ref, accountNumber) {
      ref.watch(authSessionProvider);
      return ref
          .read(coreAccountServiceProvider)
          .getAccountSummary(accountNumber);
    });
