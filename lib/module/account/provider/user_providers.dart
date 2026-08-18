import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/user_profile_model.dart';
import '../model/user_tier_model.dart';
import '../service/user_service.dart';

final userProfileProvider =
    NotifierProvider<UserProfileNotifier, NotifierState<UserOwnProfileData>>(
      UserProfileNotifier.new,
    );

class UserProfileNotifier extends Notifier<NotifierState<UserOwnProfileData>> {
  @override
  NotifierState<UserOwnProfileData> build() => const NotifierState.idle();

  Future<NotifierState<UserOwnProfileData>> load() async {
    state = NotifierState.loading(data: state.data);
    state = await ref.read(userServiceProvider).getOwnProfile();
    return state;
  }

  void markPinCreated() {
    final profile = state.data;
    if (profile != null) {
      state = NotifierState.done(profile.copyWith(isCreatedPin: true));
    }
  }

  void clear() => state = const NotifierState.idle();
}

final userTierProvider =
    NotifierProvider<UserTierNotifier, NotifierState<UserTierInfoData>>(
      UserTierNotifier.new,
    );

class UserTierNotifier extends Notifier<NotifierState<UserTierInfoData>> {
  @override
  NotifierState<UserTierInfoData> build() => const NotifierState.idle();

  Future<NotifierState<UserTierInfoData>> load() async {
    state = NotifierState.loading(data: state.data);
    state = await ref.read(userServiceProvider).getOwnTier();
    return state;
  }

  void clear() => state = const NotifierState.idle();
}
