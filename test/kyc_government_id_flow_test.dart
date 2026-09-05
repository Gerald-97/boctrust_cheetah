import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/user_tier_model.dart';
import 'package:boctrust_savings_loan/module/account/service/user_service.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/provider/kyc_providers.dart';
import 'package:boctrust_savings_loan/module/kyc/service/kyc_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _initiationJson() => {
  'verificationId': 'verification-1',
  'product': 'enhanced_document_verification',
  'sdkJobType': 'enhancedDocumentVerification',
  'environment': 'sandbox',
  'country': 'NG',
  'documentType': 'voter_id',
  'smileUserId': 'smile-user-1',
  'smileJobId': 'smile-job-1',
  'callbackUrl': 'https://user.example.test/document-webhook',
  'partnerParams': {'job_type': 11},
};

class _FakeKycService implements KycService {
  _FakeKycService(this._responses);

  final List<NotifierState<KycInitiationData>> _responses;
  int initiateCalls = 0;

  @override
  Future<NotifierState<KycInitiationData>> initiateGovernmentId(
    GovernmentIdVerificationRequest request,
  ) async {
    final response = _responses[initiateCalls.clamp(0, _responses.length - 1)];
    initiateCalls++;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Initiation refreshes the tier, so that dependency must be satisfied too.
class _StubUserService implements UserService {
  int tierCalls = 0;

  @override
  Future<NotifierState<UserTierInfoData>> getOwnTier() async {
    tierCalls++;
    return const NotifierState<UserTierInfoData>.error('stub');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _StubUserService users;

  setUp(() => users = _StubUserService());

  ProviderContainer containerWith(_FakeKycService kyc) {
    final container = ProviderContainer(
      overrides: [
        kycServiceProvider.overrideWithValue(kyc),
        userServiceProvider.overrideWithValue(users),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a fresh initiation returns the job context capture needs', () async {
    final kyc = _FakeKycService([
      NotifierState.done(KycInitiationData.fromJson(_initiationJson())),
    ]);
    final container = containerWith(kyc);

    final initiation = await container
        .read(governmentIdVerificationProvider.notifier)
        .submit(documentType: GovernmentIdDocumentType.voterId);

    expect(initiation, isNotNull);
    expect(initiation!.smileJobId, 'smile-job-1');
    expect(
      container.read(governmentIdVerificationProvider).data!.stage,
      KycFlowStage.awaitingProvider,
    );
  });

  test('cancelling then retrying reuses the cached job, without a second '
      'initiation request', () async {
    // A 409 on the second call, with no job context in the body: the cache is
    // what keeps the flow resumable in this process.
    final kyc = _FakeKycService([
      NotifierState.done(KycInitiationData.fromJson(_initiationJson())),
      const NotifierState<KycInitiationData>.error(
        'Verification already in progress.',
        statusCode: 409,
      ),
    ]);
    final container = containerWith(kyc);
    final notifier = container.read(governmentIdVerificationProvider.notifier);

    await notifier.submit(documentType: GovernmentIdDocumentType.voterId);
    // The user backed out of the capture screen.
    notifier.markAwaitingProvider();

    final resumed = await notifier.submit(
      documentType: GovernmentIdDocumentType.voterId,
    );

    expect(resumed, isNotNull, reason: 'the cached job must reopen capture');
    expect(resumed!.smileJobId, 'smile-job-1');
    expect(
      kyc.initiateCalls,
      1,
      reason: 'reopening a cached job must not hit the network',
    );
    expect(container.read(governmentIdVerificationProvider).isDone, isTrue);
  });

  test('after a process restart a bare 409 cannot reopen capture', () async {
    // clear() stands in for a restart: the cached initiation is gone, and the
    // backend does not yet return the existing job context on 409. This is the
    // named backend blocker; the honest behaviour is a blocked card.
    final kyc = _FakeKycService([
      const NotifierState<KycInitiationData>.error(
        'Verification already in progress.',
        statusCode: 409,
      ),
    ]);
    final container = containerWith(kyc);
    final notifier = container.read(governmentIdVerificationProvider.notifier);
    notifier.clear();

    final resumed = await notifier.submit(
      documentType: GovernmentIdDocumentType.voterId,
    );

    expect(resumed, isNull);
    final state = container.read(governmentIdVerificationProvider);
    expect(state.isDone, isTrue, reason: 'in progress is not an error');
    expect(state.data!.stage, KycFlowStage.awaitingProvider);
    expect(state.data!.stage, isNot(KycFlowStage.pendingReview));
  });

  test('a 409 carrying job context reopens capture', () async {
    final kyc = _FakeKycService([
      NotifierState<KycInitiationData>.error(
        'Verification already in progress.',
        statusCode: 409,
        data: KycInitiationData.fromJson(_initiationJson()),
      ),
    ]);
    final container = containerWith(kyc);

    final resumed = await container
        .read(governmentIdVerificationProvider.notifier)
        .submit(documentType: GovernmentIdDocumentType.voterId);

    expect(resumed, isNotNull);
    expect(resumed!.smileUserId, 'smile-user-1');
  });

  test('outcome methods move the stage without ever claiming verified', () {
    final kyc = _FakeKycService([
      NotifierState.done(KycInitiationData.fromJson(_initiationJson())),
    ]);
    final container = containerWith(kyc);
    final notifier = container.read(governmentIdVerificationProvider.notifier);

    notifier.markPendingReview();
    expect(
      container.read(governmentIdVerificationProvider).data!.stage,
      KycFlowStage.pendingReview,
    );

    notifier.markProviderFailure();
    expect(
      container.read(governmentIdVerificationProvider).data!.stage,
      KycFlowStage.failed,
    );

    // No stage a client can assign to itself means verified.
    expect(KycFlowStage.values.map((s) => s.name), isNot(contains('verified')));
  });

  test('a provider failure keeps the cached job retryable', () async {
    final kyc = _FakeKycService([
      NotifierState.done(KycInitiationData.fromJson(_initiationJson())),
    ]);
    final container = containerWith(kyc);
    final notifier = container.read(governmentIdVerificationProvider.notifier);

    await notifier.submit(documentType: GovernmentIdDocumentType.voterId);
    notifier.markProviderFailure();

    expect(
      container.read(governmentIdVerificationProvider).data!.initiation,
      isNotNull,
    );
  });

  test('only voter ID is cleared for enhanced document verification', () {
    expect(
      GovernmentIdDocumentType.voterId.isEnhancedDocumentVerificationEnabled,
      isTrue,
    );
    for (final type in GovernmentIdDocumentType.values.where(
      (type) => type != GovernmentIdDocumentType.voterId,
    )) {
      expect(
        type.isEnhancedDocumentVerificationEnabled,
        isFalse,
        reason: '${type.wireValue} has no successful sandbox submission yet',
      );
    }
  });
}
