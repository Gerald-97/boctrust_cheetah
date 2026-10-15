import 'package:boctrust_savings_loan/app/auth_navigation_provider.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_requests.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_responses.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/post_login_bootstrap_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/security_action_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/responsive_fixtures.dart';

class _Profile extends LayoutProfile {
  _Profile(this.hasPin);
  final bool hasPin;

  @override
  NotifierState<UserOwnProfileData> build() =>
      NotifierState.done(super.build().data!.copyWith(isCreatedPin: hasPin));

  @override
  Future<NotifierState<UserOwnProfileData>> load() async => state;
}

class _Tiers extends LayoutTiers {
  @override
  Future<NotifierState<UserTierInfoData>> load() async => state;
}

class _Home extends LayoutHome {
  @override
  Future<NotifierState<UserHomeData>> load() async => state;
}

class _Auth extends AuthService {
  _Auth(this.confirmed) : super(ApiService(Dio()));
  final bool confirmed;
  String? submittedPin;

  @override
  Future<NotifierState<CreateFirstPinData>> createFirstPin(
    CreateFirstPinRequest request,
  ) async {
    submittedPin = request.pin;
    return NotifierState.done(
      CreateFirstPinData(userId: 'layout', isCreatedPin: confirmed),
    );
  }
}

ProviderContainer _container({required bool hasPin, _Auth? auth}) =>
    ProviderContainer(
      overrides: [
        userProfileProvider.overrideWith(() => _Profile(hasPin)),
        userTierProvider.overrideWith(_Tiers.new),
        userHomeProvider.overrideWith(_Home.new),
        if (auth != null) authServiceProvider.overrideWithValue(auth),
      ],
    );

void main() {
  test(
    'post-login bootstrap sends an account without a PIN to PIN setup',
    () async {
      final container = _container(hasPin: false);
      addTearDown(container.dispose);

      final destination = await container
          .read(postLoginBootstrapProvider.notifier)
          .load();

      expect(destination, AuthDestination.createFirstPin);
    },
  );

  test('post-login bootstrap opens Home when the PIN already exists', () async {
    final container = _container(hasPin: true);
    addTearDown(container.dispose);

    final destination = await container
        .read(postLoginBootstrapProvider.notifier)
        .load();

    expect(destination, AuthDestination.home);
  });

  test('creating the first PIN marks the profile and opens Home', () async {
    final auth = _Auth(true);
    final container = _container(hasPin: false, auth: auth);
    addTearDown(container.dispose);

    await container.read(createFirstPinProvider.notifier).submit('6382');

    expect(auth.submittedPin, '6382');
    expect(container.read(userProfileProvider).data?.isCreatedPin, isTrue);
    expect(
      container.read(authNavigationProvider).last.destination,
      AuthDestination.home,
    );
  });

  test('unconfirmed PIN response keeps the user on PIN setup', () async {
    final auth = _Auth(false);
    final container = _container(hasPin: false, auth: auth);
    addTearDown(container.dispose);

    await container.read(createFirstPinProvider.notifier).submit('6382');

    expect(container.read(createFirstPinProvider).isError, isTrue);
    expect(container.read(userProfileProvider).data?.isCreatedPin, isFalse);
    expect(container.read(authNavigationProvider), isEmpty);
  });
}
