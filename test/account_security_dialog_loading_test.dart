import 'dart:async';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/helper/app_open_recency.dart';
import 'package:boctrust_savings_loan/helper/biometric_auth_service.dart';
import 'package:boctrust_savings_loan/helper/biometric_login_storage.dart';
import 'package:boctrust_savings_loan/helper/biometric_transfer_storage.dart';
import 'package:boctrust_savings_loan/helper/secure_storage.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_requests.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_responses.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/remembered_biometric_profile.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/memory_secure_storage.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

class _PendingAuth extends AuthService {
  _PendingAuth() : super(ApiService(Dio()));

  final password = Completer<NotifierState<EmptyData>>();
  final pin = Completer<NotifierState<EmptyData>>();
  final verification = Completer<NotifierState<EmptyData>>();
  var passwordCalls = 0;
  var pinCalls = 0;
  var verificationCalls = 0;

  @override
  Future<NotifierState<EmptyData>> changePassword(
    ChangePasswordRequest request,
  ) {
    passwordCalls++;
    return password.future;
  }

  @override
  Future<NotifierState<EmptyData>> changePin(ChangePinRequest request) {
    pinCalls++;
    return pin.future;
  }

  @override
  Future<NotifierState<EmptyData>> verifyCurrentPassword(
    VerifyCurrentPasswordRequest request,
  ) {
    verificationCalls++;
    return verification.future;
  }

  @override
  Future<NotifierState<EmptyData>> verifyCurrentPin(
    VerifyCurrentPinRequest request,
  ) {
    verificationCalls++;
    return verification.future;
  }
}

/// A fingerprint device whose prompt resolves when the test says so.
class _PendingPromptGateway implements BiometricAuthGateway {
  final prompt = Completer<BiometricAuthOutcome>();
  var prompts = 0;

  @override
  Future<BiometricCapability> checkCapability() async =>
      const BiometricCapability(
        supported: true,
        presentation: BiometricPresentation.fingerprint,
        reason: null,
      );

  @override
  Future<BiometricAuthOutcome> authenticate({required String reason}) {
    prompts++;
    return prompt.future;
  }

  @override
  Future<void> stopAuthentication() async {}
}

Future<void> _openSecurityCenter(WidgetTester tester, _PendingAuth auth) async {
  await pumpFlow(
    tester,
    route: AppRoutes.securitySettings,
    overrides: [
      authServiceProvider.overrideWithValue(auth),
      userProfileProvider.overrideWith(LayoutProfile.new),
    ],
  );
}

Finder _dialogAction() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(FilledButton),
);

void main() {
  testWidgets('Security Center hides device and contact change controls', (
    tester,
  ) async {
    await _openSecurityCenter(tester, _PendingAuth());

    expect(find.text('Device management'), findsNothing);
    expect(find.text('Change mobile number'), findsNothing);
    expect(find.text('Change email'), findsNothing);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Transaction PIN'), findsOneWidget);
  });

  testWidgets('change password shows one busy Update action', (tester) async {
    final auth = _PendingAuth();
    await _openSecurityCenter(tester, auth);
    await tester.tap(find.text('Password').first);
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'CurrentPass1!');
    await tester.enterText(fields.at(1), 'NewPassword1!');
    await tester.enterText(fields.at(2), 'NewPassword1!');
    await tester.tap(find.text('Update'));
    await tester.pump();

    expect(auth.passwordCalls, 1);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_dialogAction()).onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
          .onPressed,
      isNull,
    );

    auth.password.complete(const NotifierState.error('Try again'));
    await tester.pumpAndSettle();
  });

  testWidgets('change PIN shows one busy Update action', (tester) async {
    final auth = _PendingAuth();
    await _openSecurityCenter(tester, auth);
    await tester.tap(find.text('Transaction PIN').first);
    await tester.pump(const Duration(milliseconds: 300));
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), '1357');
    await tester.enterText(fields.at(1), '6382');
    await tester.enterText(fields.at(2), '6382');
    await tester.tap(find.text('Update'));
    await tester.pump();

    expect(auth.pinCalls, 1);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_dialogAction()).onPressed, isNull);

    auth.pin.complete(const NotifierState.error('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('current password verification shows busy Verify action', (
    tester,
  ) async {
    final auth = _PendingAuth();
    await _openSecurityCenter(tester, auth);
    await tester.tap(find.text('Security checks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify current password').first);
    await tester.pumpAndSettle();
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, 'CurrentPass1!');
    await tester.tap(find.text('Verify').last);
    await tester.pump();

    expect(auth.verificationCalls, 1);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_dialogAction()).onPressed, isNull);

    auth.verification.complete(const NotifierState.error('Try again'));
    await tester.pumpAndSettle();
  });

  testWidgets('current PIN verification shows busy Verify action', (
    tester,
  ) async {
    final auth = _PendingAuth();
    await _openSecurityCenter(tester, auth);
    await tester.tap(find.text('Security checks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify current PIN').first);
    await tester.pump(const Duration(milliseconds: 300));
    final field = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(field, '6382');
    await tester.tap(find.text('Verify').last);
    await tester.pump();

    expect(auth.verificationCalls, 1);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(_dialogAction()).onPressed, isNull);

    auth.verification.complete(const NotifierState.error('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
    'enabling transfer approval succeeds only after server PIN verification '
    'and a successful prompt',
    (tester) async {
      final auth = _PendingAuth();
      final gateway = _PendingPromptGateway();
      final secure = SecureStorage(storage: MemorySecureStorage());
      final transfers = BiometricTransferStorage(secure);
      // The test binding never reports a foreground state; record the
      // launch the app would otherwise wait for.
      final recency = AppOpenRecency(
        secure,
        BiometricLoginStorage(secure),
        transfers,
      )..recordColdLaunch();
      await pumpFlow(
        tester,
        route: AppRoutes.securitySettings,
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          userProfileProvider.overrideWith(LayoutProfile.new),
          authSessionProvider.overrideWith(SavingsSession.new),
          biometricAuthGatewayProvider.overrideWithValue(gateway),
          biometricTransferStorageProvider.overrideWithValue(transfers),
          appOpenRecencyProvider.overrideWithValue(recency),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));
      final toggle = find.descendant(
        of: find
            .ancestor(
              of: find.text('Fingerprint for transfers'),
              matching: find.byType(InkWell),
            )
            .first,
        matching: find.byType(Switch),
      );
      bool isOn() => tester.widget<Switch>(toggle).value;

      await tester.tap(find.text('Fingerprint for transfers'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextFormField),
        ),
        '1357',
      );
      await tester.tap(_dialogAction());
      await tester.pump();

      expect(auth.verificationCalls, 1);
      expect(gateway.prompts, 0);

      auth.verification.complete(const NotifierState.done(EmptyData()));
      await tester.pump();
      expect(gateway.prompts, 1);
      expect(isOn(), isFalse);

      gateway.prompt.complete(BiometricAuthOutcome.success);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(isOn(), isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        await tester.runAsync(transfers.loadValidEnrollment),
        savingsSession().userId,
      );
    },
  );
}
