import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/profile_image_model.dart';
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

final profileImageSignedUrlProvider =
    NotifierProvider<
      ProfileImageSignedUrlNotifier,
      NotifierState<ProfileImageSignedUrlData>
    >(ProfileImageSignedUrlNotifier.new);

/// Fetches and refreshes the short-lived signed URL for a private profile
/// image.
///
/// The URL is in-memory only and expiry is computed locally from the issue
/// time. A missing image is an empty state, not an error: it must never raise
/// a page-level failure.
class ProfileImageSignedUrlNotifier
    extends Notifier<NotifierState<ProfileImageSignedUrlData>> {
  @override
  NotifierState<ProfileImageSignedUrlData> build() =>
      const NotifierState.idle();

  bool _inFlight = false;

  /// True once a load has been attempted for the current session, so a failed
  /// or empty result is not retried on every rebuild.
  bool _attempted = false;

  /// Loads a signed URL when one is needed.
  ///
  /// Returns early when a valid unexpired URL is already held, when a request
  /// is in flight, or when a previous attempt already resolved — unless [force]
  /// is set, which is how a 403 on image load requests exactly one replacement.
  Future<void> ensureLoaded({bool force = false}) async {
    if (_inFlight) return;
    final current = state.data;
    if (!force && current != null && !current.isExpired) return;
    if (!force && _attempted && current == null) return;

    _inFlight = true;
    _attempted = true;
    state = NotifierState.loading(data: force ? null : state.data);
    try {
      final result = await ref
          .read(userServiceProvider)
          .getProfileImageSignedUrl();
      // A missing image is an empty avatar state, never a screen error.
      state = result.isError && result.statusCode == 404
          ? const NotifierState.empty()
          : result;
    } finally {
      _inFlight = false;
    }
  }

  /// Called when an image load fails with 403: the URL lapsed between issue
  /// and use. Requests exactly one replacement; [_attempted] plus the in-flight
  /// guard prevent a refresh loop.
  Future<void> refreshAfterForbidden() => ensureLoaded(force: true);

  void clear() {
    _attempted = false;
    _inFlight = false;
    state = const NotifierState.idle();
  }
}
