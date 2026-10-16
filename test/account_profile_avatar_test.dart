import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/profile_image_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

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

void main() {
  testWidgets('Account avatar uses the HTTPS image URL from the profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await flowTestOverrides(),
          userProfileProvider.overrideWith(_ProfileWithImage.new),
        ],
        child: flowApp(route: AppRoutes.account),
      ),
    );

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

  testWidgets('a failed profile URL falls back to the signed image URL', (
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
