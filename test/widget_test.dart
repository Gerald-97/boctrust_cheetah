import 'package:boctrust_savings_loan/app.dart';
import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/theme_controller.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:boctrust_savings_loan/module/component/text_fields.dart';
import 'package:boctrust_savings_loan/utils/form_helpers.dart';
import 'package:boctrust_savings_loan/utils/input_formatters.dart';
import 'package:boctrust_savings_loan/utils/validators.dart' as validators;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app launches into the live prototype onboarding flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      CheetahTestApp(
        preferences: preferences,
        initialRoute: AppRoutes.onboarding,
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Save without thinking about it'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('login route shows the live prototype PIN login screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      CheetahTestApp(preferences: preferences, initialRoute: AppRoutes.login),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('theme mode restores saved dark value', (tester) async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'dark'});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(CheetahTestApp(preferences: preferences));
    await tester.pump(const Duration(milliseconds: 250));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('theme mode invalid saved value falls back to system', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({themePreferenceKey: 'invalid'});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(CheetahTestApp(preferences: preferences));
    await tester.pump(const Duration(milliseconds: 250));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('PhoneNumberInput forwards autovalidate mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: PhoneNumberInput(
              autoValidateMode: AutovalidateMode.onUserInteraction,
              validator: validators.nigerianPhone,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.pump();
    expect(find.text('Input a valid phone number'), findsOneWidget);
  });

  testWidgets('FormDropdown participates in validation', (tester) async {
    final key = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: FormDropdown<String>(
              items: const [DropdownMenuItem(value: 'one', child: Text('One'))],
              onChanged: (_) {},
              validator: (value) => validators.requiredPicker(value),
            ),
          ),
        ),
      ),
    );

    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Please select an option'), findsOneWidget);
  });

  test('validators cover common Cheetah form rules', () {
    expect(validators.requiredText('   '), isNotNull);
    expect(validators.optionalName('A'), isNotNull);
    expect(validators.email('user@example.com'), isNull);
    expect(validators.nigerianPhone('0800-000-0000'), isNull);
    expect(validators.isPasswordValid('Password1'), isNotNull);
    expect(validators.isPasswordValid('Password1!'), isNull);
    expect(validators.confirmPassword('Password1!', 'Password1!'), isNull);
    expect(validators.otp('123456'), isNull);
    expect(validators.transactionPin('1357'), isNull);
    expect(validators.strongTransactionPin('1234'), isNotNull);
    expect(validators.strongTransactionPin('1111'), isNotNull);
    expect(validators.strongTransactionPin('7890'), isNull);
    expect(validators.bvn('12345678901'), isNull);
    expect(validators.nin('12345678901'), isNull);
    expect(validators.bankAccountNumber('1234567890'), isNull);
    expect(validators.nairaAmountRange('1,000', min: 500, max: 2000), isNull);
    expect(validators.conditionalOtherText('', isOther: true), isNotNull);
    expect(validators.fileUploadRequired(null), isNotNull);
  });

  test('input formatters normalize constrained input', () {
    final phone = PhoneDashFormatter().formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '08000000000'),
    );
    expect(phone.text, '0800-000-0000');
    final amount = NairaThousandsFormatter().formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '1000000'),
    );
    expect(amount.text, '1,000,000');
    final upper = UppercaseTrimFormatter().formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: ' abc123 '),
    );
    expect(upper.text, 'ABC123 ');
    final max = MaxLengthDigitsFormatter(4).formatEditUpdate(
      const TextEditingValue(),
      const TextEditingValue(text: '123456'),
    );
    expect(max.text, '1234');
  });

  testWidgets('validateAndSave calls success or failure guardrails', (
    tester,
  ) async {
    final key = GlobalKey<FormState>();
    var success = false;
    AutovalidateMode? failureMode;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: key,
            child: TextFormField(validator: validators.requiredText),
          ),
        ),
      ),
    );

    final failed = validateAndSave(
      formKey: key,
      onSuccess: () => success = true,
      onFailure: (mode) => failureMode = mode,
    );
    expect(failed, isFalse);
    expect(success, isFalse);
    expect(failureMode, AutovalidateMode.onUserInteraction);

    await tester.enterText(find.byType(TextFormField), 'Ada');
    final passed = validateAndSave(
      formKey: key,
      onSuccess: () => success = true,
      onFailure: (mode) => failureMode = mode,
    );
    expect(passed, isTrue);
    expect(success, isTrue);
  });

  test('all registered routes include required UX parity routes', () {
    expect(AppRoutes.allRoutes, contains(AppRoutes.transactionAuthorization));
    expect(AppRoutes.allRoutes, contains(AppRoutes.notifications));
    expect(AppRoutes.allRoutes, contains(AppRoutes.loansNotifyMe));
    expect(AppRoutes.allRoutes, contains(AppRoutes.cardsNotifyMe));
  });

  test('linked banks resolves to the live screen, not a preview', () {
    expect(appScreenForRoute(AppRoutes.linkedBanks), AppScreen.linkedBanks);
    // The preview route is gone, so no fabricated bank rows can be rendered.
    expect(
      AppPreviewRoute.values.map((route) => route.name),
      isNot(contains('accountLinkedBanks')),
    );
    expect(appPreviewRouteForRoute(AppRoutes.linkedBanks), isNull);
  });
}
