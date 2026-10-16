import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _VerifiedPhoneProfile extends UserProfileNotifier {
  @override
  NotifierState<UserOwnProfileData> build() => NotifierState.done(
    UserOwnProfileData.fromJson({
      'userId': 'ada',
      'firstName': 'Ada',
      'lastName': 'Lovelace',
      'email': 'ada@example.test',
      'phoneNumber': '+2348012345678',
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

class _LoadablePhoneProfile extends _VerifiedPhoneProfile {
  @override
  NotifierState<UserOwnProfileData> build() => const NotifierState.idle();

  @override
  Future<NotifierState<UserOwnProfileData>> load() async {
    state = super.build();
    return state;
  }
}

void main() {
  testWidgets('My profile displays a verified phone number', (tester) async {
    await pumpFlow(
      tester,
      route: AppRoutes.myProfile,
      overrides: [userProfileProvider.overrideWith(_VerifiedPhoneProfile.new)],
    );

    expect(find.text('Phone number'), findsOneWidget);
    expect(find.text('+2348012345678'), findsOneWidget);
  });

  testWidgets('opening My profile directly loads the phone number', (
    tester,
  ) async {
    await pumpFlow(
      tester,
      route: AppRoutes.myProfile,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        userProfileProvider.overrideWith(_LoadablePhoneProfile.new),
      ],
    );
    await tester.pump();

    expect(find.text('+2348012345678'), findsOneWidget);
  });
}
