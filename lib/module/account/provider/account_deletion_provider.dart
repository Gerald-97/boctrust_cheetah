import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/model/auth_responses.dart';
import '../model/account_deletion_models.dart';

const _unavailable = 'Account deletion is not available yet.';

/// No deletion contract exists yet: both notifiers report unavailability, and
/// the delete-account flow is gated by `FeatureCapability.accountDeletion` so
/// neither is reached until the endpoints, models and service land.
final accountDeletionEligibilityProvider =
    NotifierProvider<
      AccountDeletionEligibilityNotifier,
      NotifierState<AccountDeletionEligibility>
    >(AccountDeletionEligibilityNotifier.new);

class AccountDeletionEligibilityNotifier
    extends Notifier<NotifierState<AccountDeletionEligibility>> {
  @override
  NotifierState<AccountDeletionEligibility> build() =>
      const NotifierState.idle();

  Future<void> load() async => state = const NotifierState.error(_unavailable);

  void clear() => state = const NotifierState.idle();
}

final accountDeletionProvider =
    NotifierProvider<AccountDeletionNotifier, NotifierState<EmptyData>>(
      AccountDeletionNotifier.new,
    );

class AccountDeletionNotifier extends Notifier<NotifierState<EmptyData>> {
  @override
  NotifierState<EmptyData> build() => const NotifierState.idle();

  Future<void> delete() async =>
      state = const NotifierState.error(_unavailable);

  void clear() => state = const NotifierState.idle();
}
