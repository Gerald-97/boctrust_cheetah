import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/profile_image_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

const _profileImage = 'https://images.example.test/ada.jpg';

class _ProfileWithImage extends UserProfileNotifier {
  @override
  NotifierState<UserOwnProfileData> build() => NotifierState.done(
    UserOwnProfileData.fromJson({
      'userId': 'ada',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
      'tier': 1,
      'status': 'active',
      'transactionStatus': 'active',
      'isVerifiedAccount': true,
      'isVerifiedEmail': true,
      'isVerifiedPhoneNumber': true,
      'isCreatedPassword': true,
      'isCreatedPin': true,
      'imageUrl': _profileImage,
    }),
  );
}

class _SignedProfileImage extends ProfileImageSignedUrlNotifier {
  @override
  NotifierState<ProfileImageSignedUrlData> build() => NotifierState.done(
    ProfileImageSignedUrlData(
      imageUrl: 'https://images.example.test/ada-signed.jpg',
      expiresInSeconds: 900,
    ),
  );
}

class _ProfileWithoutImage extends UserProfileNotifier {
  @override
  NotifierState<UserOwnProfileData> build() => NotifierState.done(
    UserOwnProfileData.fromJson({
      'userId': 'ada',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
      'tier': 1,
      'status': 'active',
      'transactionStatus': 'active',
      'isVerifiedAccount': true,
      'isVerifiedEmail': true,
      'isVerifiedPhoneNumber': true,
      'isCreatedPassword': true,
      'isCreatedPin': true,
    }),
  );
}

class _ImageService extends UserService {
  _ImageService() : super(ApiService(Dio()));

  int signedUrlReads = 0;

  @override
  Future<NotifierState<ProfileImageSignedUrlData>>
  getProfileImageSignedUrl() async {
    signedUrlReads++;
    return NotifierState.done(
      ProfileImageSignedUrlData(
        imageUrl: 'https://images.example.test/ada-signed.jpg',
        expiresInSeconds: 900,
      ),
    );
  }
}

class _NoSignedImageService extends UserService {
  _NoSignedImageService() : super(ApiService(Dio()));

  @override
  Future<NotifierState<ProfileImageSignedUrlData>>
  getProfileImageSignedUrl() async => const NotifierState.empty();
}

void main() {
  testWidgets('Account requests the signed URL even without a profile URL', (
    tester,
  ) async {
    final service = _ImageService();
    await pumpFlow(
      tester,
      route: AppRoutes.account,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        userProfileProvider.overrideWith(_ProfileWithoutImage.new),
        userServiceProvider.overrideWithValue(service),
      ],
    );
    await tester.pump();

    expect(service.signedUrlReads, 1);
    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(ProfileAvatar),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://images.example.test/ada-signed.jpg',
    );
  });

  testWidgets('Account avatar uses the HTTPS image URL from the profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          userProfileProvider.overrideWith(_ProfileWithImage.new),
          userServiceProvider.overrideWithValue(_NoSignedImageService()),
        ],
        child: flowApp(route: AppRoutes.account),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(ProfileAvatar),
        matching: find.byType(Image),
      ),
    );
    expect((image.image as NetworkImage).url, _profileImage);
  });

  test('profile also reads the image_url spelling', () {
    final profile = UserOwnProfileData.fromJson({
      'userId': 'ada',
      'tier': 1,
      'status': 'active',
      'transactionStatus': 'active',
      'isVerifiedAccount': true,
      'isVerifiedEmail': true,
      'isVerifiedPhoneNumber': true,
      'isCreatedPassword': true,
      'isCreatedPin': true,
      'image_url': _profileImage,
    });

    expect(profile.imageUrl, _profileImage);
  });

  testWidgets('a signed image URL takes priority over the profile URL', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      route: AppRoutes.account,
      overrides: [
        userProfileProvider.overrideWith(_ProfileWithImage.new),
        profileImageSignedUrlProvider.overrideWith(_SignedProfileImage.new),
      ],
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(ProfileAvatar),
        matching: find.byType(Image),
      ),
    );
    expect(
      (image.image as NetworkImage).url,
      'https://images.example.test/ada-signed.jpg',
    );
  });
}
