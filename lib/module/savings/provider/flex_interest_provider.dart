import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/flex_interest_models.dart';
import '../service/core_flex_interest_service.dart';

/// The customer's Flex interest. Re-read when the session changes, so it
/// never outlives the customer it belongs to.
final flexInterestProvider =
    FutureProvider.autoDispose<NotifierState<FlexInterest>>((ref) {
      ref.watch(authSessionProvider);
      return ref.read(coreFlexInterestServiceProvider).getInterest();
    });
