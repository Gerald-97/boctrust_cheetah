import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/services.dart';
import '../../account/provider/user_providers.dart';
import '../model/auth_flow_models.dart';
import 'fcm_token_provider.dart';

final postLoginBootstrapProvider =
    NotifierProvider<
      PostLoginBootstrapNotifier,
      NotifierState<PostLoginBootstrapData>
    >(PostLoginBootstrapNotifier.new);

class PostLoginBootstrapNotifier
    extends Notifier<NotifierState<PostLoginBootstrapData>> {
  @override
  NotifierState<PostLoginBootstrapData> build() =>
      const NotifierState.idle(data: PostLoginBootstrapData());

  Future<AuthDestination?> load() async {
    state = const NotifierState.loading(
      data: PostLoginBootstrapData(
        stage: PostLoginBootstrapStage.loadingProfile,
      ),
    );
    final profileState = await ref.read(userProfileProvider.notifier).load();
    final profile = profileState.data;
    if (!profileState.isDone || profile == null) {
      state = NotifierState.error(
        profileState.message ?? 'Unable to load your profile.',
        data: const PostLoginBootstrapData(
          stage: PostLoginBootstrapStage.profileError,
        ),
        statusCode: profileState.statusCode,
        errorCode: profileState.errorCode,
        errors: profileState.errors,
        meta: profileState.meta,
        noAuth: profileState.noAuth,
      );
      return null;
    }

    state = NotifierState.done(
      PostLoginBootstrapData(
        stage: PostLoginBootstrapStage.ready,
        profile: profile,
      ),
      message: profileState.message,
      statusCode: profileState.statusCode,
      meta: profileState.meta,
    );
    unawaited(ref.read(userTierProvider.notifier).load());
    unawaited(ref.read(fcmTokenProvider.notifier).registerAfterBootstrap());
    return profile.isCreatedPin
        ? AuthDestination.home
        : AuthDestination.createFirstPin;
  }
}
