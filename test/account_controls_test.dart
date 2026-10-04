import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/account_deletion_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/account_deletion_provider.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_responses.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/security_action_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'support/flow_harness.dart';

class ZeroBalanceEligibility extends AccountDeletionEligibilityNotifier {
  @override
  Future<void> load() async => state = const NotifierState.done(
    AccountDeletionEligibility(canDelete: true),
  );
}

class CountingDeletion extends AccountDeletionNotifier {
  int calls = 0;

  @override
  Future<void> delete() async {
    calls++;
    state = const NotifierState.done(EmptyData());
  }
}

class ScriptedPinCheck extends VerifyCurrentPinNotifier {
  bool accept = false;

  @override
  Future<void> submit(String pin) async => state = accept
      ? const NotifierState.done(EmptyData())
      : const NotifierState.error('That PIN is incorrect.');
}

void main() {
  testWidgets('account deletion is sent only after the current PIN verifies', (
    tester,
  ) async {
    final deletion = CountingDeletion();
    final pinCheck = ScriptedPinCheck();
    await pumpFlow(
      tester,
      route: AppRoutes.deleteAccount,
      overrides: [
        featureAvailabilityProvider(
          FeatureCapability.accountDeletion,
        ).overrideWithValue(FeatureAvailability.available),
        accountDeletionEligibilityProvider.overrideWith(
          ZeroBalanceEligibility.new,
        ),
        accountDeletionProvider.overrideWith(() => deletion),
        verifyCurrentPinProvider.overrideWith(() => pinCheck),
      ],
    );

    await tester.tap(find.widgetWithText(PrimaryButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DestructiveButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(deletion.calls, 0, reason: 'confirming alone must not delete');

    await tester.enterText(find.byType(EditableText).last, '1234');
    await tester.tap(find.widgetWithText(PrimaryButton, 'Verify and delete'));
    await tester.pumpAndSettle();
    expect(deletion.calls, 0, reason: 'a rejected PIN must not delete');

    pinCheck.accept = true;
    await tester.tap(find.widgetWithText(PrimaryButton, 'Verify and delete'));
    await tester.pumpAndSettle();
    expect(deletion.calls, 1);
  });
}
