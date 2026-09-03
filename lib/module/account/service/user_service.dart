import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/profile_image_model.dart';
import '../model/user_profile_model.dart';
import '../model/user_tier_model.dart';

final userServiceProvider = Provider<UserService>(
  (ref) => UserService(ref.watch(apiServiceProvider)),
);

class UserService {
  const UserService(this._api);
  final ApiService _api;

  Future<NotifierState<UserOwnProfileData>> getOwnProfile() async =>
      NotifierState.fromResponse(
        await _api.getData<UserOwnProfileData>(
          ApiEndpoints.ownProfile,
          parser: UserOwnProfileData.fromJson,
        ),
      );

  Future<NotifierState<UserTierInfoData>> getOwnTier() async =>
      NotifierState.fromResponse(
        await _api.getData<UserTierInfoData>(
          ApiEndpoints.ownTier,
          parser: UserTierInfoData.fromJson,
        ),
      );

  Future<NotifierState<ProfileImageSignedUrlData>>
  getProfileImageSignedUrl() async => NotifierState.fromResponse(
    await _api.getData<ProfileImageSignedUrlData>(
      ApiEndpoints.profileImageSignedUrl,
      parser: ProfileImageSignedUrlData.fromJson,
    ),
  );
}
