import 'dart:async';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_requests.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_responses.dart';
import 'package:boctrust_savings_loan/module/onboarding/service/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';

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
}
