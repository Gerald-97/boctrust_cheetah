import 'dart:async';

import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_profile_model.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/service/home_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_status_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_status_provider.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KycStatusData', () {
    test('parses every published KYC status section', () {
      final data = KycStatusData.fromJson({
        'userId': 'user-1',
        'tier': 1,
        'identity': {
          'status': 'success',
          'identityType': 'bvn',
          'identityLast4': '8901',
          'hasBvnOrNin': true,
          'hasLivenessSelfie': false,
          'failureReason': null,
          'updatedAt': '2026-09-05T10:00:00.000Z',
        },
        'governmentId': {
          'status': 'pending',
          'documentType': 'voter_id',
          'documentNumberLast4': '4567',
          'failureReason': null,
          'updatedAt': '2026-09-05T10:01:00.000Z',
        },
        'utilityBill': {
          'status': 'not_started',
          'failureReason': null,
          'reviewNotes': null,
          'updatedAt': null,
        },
        'nextAction': 'verify_government_id',
      });
      expect(data.identity.hasBvnOrNin, isTrue);
      expect(data.identity.hasLivenessSelfie, isFalse);
      expect(data.governmentId.status, KycVerificationStatus.pending);
      expect(data.nextAction, KycNextAction.verifyGovernmentId);
    });

    test('unknown status and next action remain non-authorizing', () {
      expect(
        KycVerificationStatus.fromWire('new_state'),
        KycVerificationStatus.unknown,
      );
      expect(KycNextAction.fromWire('new_action'), KycNextAction.unknown);
    });
  });

  group('refreshKycAuthoritativeState', () {
    late _FakeKycService kyc;
    late _FakeUserService user;
    late _FakeHomeService home;
    late ProviderContainer container;

    setUp(() {
      kyc = _FakeKycService();
      user = _FakeUserService();
      home = _FakeHomeService();
      container = ProviderContainer(
        overrides: [
          kycServiceProvider.overrideWithValue(kyc),
          userServiceProvider.overrideWithValue(user),
          homeServiceProvider.overrideWithValue(home),
        ],
      );
      addTearDown(container.dispose);
    });

    test('refreshes all four authoritative providers once', () async {
      await container.read(kycAuthoritativeRefreshProvider)();

      expect(kyc.statusCalls, 1);
      expect(user.profileCalls, 1);
      expect(user.tierCalls, 1);
      expect(home.homeCalls, 1);
    });

    test('concurrent callers share one in-flight round of requests', () async {
      // Resume, manual Refresh, and a post-submission refresh routinely land
      // together. Without the guard this would be twelve requests, not four.
      kyc.gate = Completer<void>();

      final first = container.read(kycAuthoritativeRefreshProvider)();
      final second = container.read(kycAuthoritativeRefreshProvider)();
      final third = container.read(kycAuthoritativeRefreshProvider)();

      kyc.gate!.complete();
      await Future.wait([first, second, third]);

      expect(kyc.statusCalls, 1);
      expect(user.profileCalls, 1);
      expect(user.tierCalls, 1);
      expect(home.homeCalls, 1);
    });

    test('a later refresh runs again once the guard is released', () async {
      await container.read(kycAuthoritativeRefreshProvider)();
      await container.read(kycAuthoritativeRefreshProvider)();

      expect(kyc.statusCalls, 2);
      expect(home.homeCalls, 2);
    });
  });
}

/// Fakes that count calls, so the shared refresh guard can be observed.
///
/// Each service is faked with noSuchMethod forwarding: only the operation the
/// fan-out calls is implemented, and any other member throws loudly rather
/// than silently returning null.
class _FakeKycService implements KycService {
  int statusCalls = 0;
  Completer<void>? gate;

  @override
  Future<NotifierState<KycStatusData>> getStatus() async {
    statusCalls++;
    await gate?.future;
    return const NotifierState<KycStatusData>.error('fake');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeUserService implements UserService {
  int profileCalls = 0;
  int tierCalls = 0;

  @override
  Future<NotifierState<UserOwnProfileData>> getOwnProfile() async {
    profileCalls++;
    return const NotifierState<UserOwnProfileData>.error('fake');
  }

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async {
    tierCalls++;
    return const NotifierState<UserTierInfoData>.error('fake');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeHomeService implements HomeService {
  int homeCalls = 0;

  @override
  Future<NotifierState<UserHomeData>> getOwnHome() async {
    homeCalls++;
    return const NotifierState<UserHomeData>.error('fake');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
