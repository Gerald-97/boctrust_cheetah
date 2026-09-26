import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/withdrawal_bank_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/withdrawal_bank_service.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_flow_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';

const _gtb = BankData(name: 'Guaranty Trust Bank', code: '058');

Map<String, Object?> _accountJson(String id, String number) => {
  'bankAccountId': id,
  'bankCode': '058',
  'bankName': 'Guaranty Trust Bank',
  'accountNumber': number,
  'accountName': 'Ada Example',
};

NotifierState<WithdrawalBankAccountListData> _list(
  List<String> numbers, {
  int maxAllowed = 3,
}) => NotifierState.done(
  WithdrawalBankAccountListData.fromJson({
    'bankAccounts': [
      for (var i = 0; i < numbers.length; i++)
        _accountJson('account-$i', numbers[i]),
    ],
    'maxAllowed': maxAllowed,
  }),
);

/// Library-private fakes cannot be shared across test files, so this UI test
/// owns its own service double.
class _FakeService implements WithdrawalBankService {
  List<NotifierState<WithdrawalBankAccountListData>> listResponses = [];
  NotifierState<AddWithdrawalBankAccountData>? addResponse;
  NotifierState<DeleteWithdrawalBankAccountData>? deleteResponse;

  int listCalls = 0;
  int resolveCalls = 0;
  AddWithdrawalBankAccountRequest? lastAdd;

  @override
  Future<NotifierState<BankCatalogueData>> getBanks() async =>
      const NotifierState.done(BankCatalogueData(banks: [_gtb]));

  @override
  Future<NotifierState<WithdrawalBankAccountListData>> listAccounts() async {
    final response =
        listResponses[listCalls.clamp(0, listResponses.length - 1)];
    listCalls++;
    return response;
  }

  @override
  Future<NotifierState<ResolveWithdrawalBankAccountData>> resolveAccount(
    ResolveWithdrawalBankAccountRequest request,
  ) async {
    resolveCalls++;
    return NotifierState.done(
      ResolveWithdrawalBankAccountData.fromJson({
        'bankCode': request.bankCode,
        'bankName': request.bankName,
        'accountNumber': request.accountNumber,
        'accountName': 'Ada Example',
        'nameMatchScore': '0.96',
        'minimumRequiredScore': '0.80',
        'isNameMatch': true,
      }),
    );
  }

  @override
  Future<NotifierState<AddWithdrawalBankAccountData>> addAccount(
    AddWithdrawalBankAccountRequest request,
  ) async {
    lastAdd = request;
    return addResponse!;
  }

  @override
  Future<NotifierState<DeleteWithdrawalBankAccountData>> deleteAccount(
    String bankAccountId,
  ) async => deleteResponse!;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _FakeService service;
  late ProviderContainer container;

  setUp(() => service = _FakeService());

  Future<void> mount(WidgetTester tester) async {
    // Tall enough that the whole add-account form is on screen.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: flowApp(route: null, screen: AppScreen.linkedBanks),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> makeContainer(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        ...await flowTestOverrides(),
        withdrawalBankServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    // Save and delete report through native toasts; there is no plugin here.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async => true,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      ),
    );
  }

  WithdrawalBankDraft draft() =>
      container.read(withdrawalBankDraftProvider).data!;

  Finder accountField() => find.descendant(
    of: find.byWidgetPredicate(
      (widget) => widget is AppTextField && widget.label == 'Account number',
    ),
    matching: find.byType(TextFormField),
  );

  /// What the customer actually sees, whether or not the field has an
  /// external controller.
  String visibleNumber(WidgetTester tester) => tester
      .widget<EditableText>(
        find.descendant(
          of: accountField(),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  VoidCallback? saveAction(WidgetTester tester) => tester
      .widget<PrimaryButton>(
        find.byWidgetPredicate(
          (widget) => widget is PrimaryButton && widget.label == 'Save account',
        ),
      )
      .onPressed;

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.text('Save account');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    // Outlast the result toast's timer.
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> seedResolvedDraft(String number) async {
    final drafts = container.read(withdrawalBankDraftProvider.notifier);
    drafts.selectBank(_gtb);
    drafts.setAccountNumber(number);
    await drafts.resolve();
    expect(draft().canSave, isTrue);
  }

  testWidgets('a pre-existing draft number is visible', (tester) async {
    service.listResponses = [_list([])];
    await makeContainer(tester);
    final drafts = container.read(withdrawalBankDraftProvider.notifier);
    drafts.selectBank(_gtb);
    drafts.setAccountNumber('0123456789');

    await mount(tester);

    expect(visibleNumber(tester), '0123456789');
    expect(visibleNumber(tester), draft().accountNumber);
    expect(find.text('Guaranty Trust Bank'), findsOneWidget);
    expect(service.resolveCalls, 0, reason: 'syncing must not resolve');
  });

  testWidgets('typing updates the draft and invalidates the resolution', (
    tester,
  ) async {
    service.listResponses = [_list([])];
    await makeContainer(tester);
    await seedResolvedDraft('0123456789');

    await mount(tester);
    expect(saveAction(tester), isNotNull);

    await tester.enterText(accountField(), '0123456780');
    await tester.pump();

    expect(visibleNumber(tester), '0123456780');
    expect(draft().accountNumber, '0123456780');
    expect(draft().resolution, isNull);
    expect(saveAction(tester), isNull);
    expect(service.resolveCalls, 1, reason: 'only the explicit seed resolved');
  });

  testWidgets('a successful save below the cap clears field and draft', (
    tester,
  ) async {
    service.listResponses = [
      _list([]),
      _list(['0123456789']),
    ];
    service.addResponse = NotifierState.done(
      AddWithdrawalBankAccountData.fromJson(
        _accountJson('account-0', '0123456789'),
      ),
    );
    await makeContainer(tester);
    await mount(tester);

    final drafts = container.read(withdrawalBankDraftProvider.notifier);
    drafts.selectBank(_gtb);
    await tester.enterText(accountField(), '0123456789');
    await tester.pump();
    await drafts.resolve();
    await tester.pump();
    expect(saveAction(tester), isNotNull);

    await tapSave(tester);

    expect(service.lastAdd!.accountNumber, '0123456789');
    expect(find.text('Account limit reached'), findsNothing);
    expect(draft().accountNumber, isEmpty);
    expect(visibleNumber(tester), isEmpty);
    expect(visibleNumber(tester), draft().accountNumber);
  });

  testWidgets('a failed save keeps field and draft', (tester) async {
    service.listResponses = [_list([])];
    service.addResponse =
        const NotifierState<AddWithdrawalBankAccountData>.error(
          'We could not save that account.',
        );
    await makeContainer(tester);
    await seedResolvedDraft('0123456789');
    await mount(tester);

    await tapSave(tester);

    expect(draft().accountNumber, '0123456789');
    expect(visibleNumber(tester), '0123456789');
  });

  testWidgets('clearing the draft clears the field', (tester) async {
    service.listResponses = [_list([])];
    await makeContainer(tester);
    await seedResolvedDraft('0123456789');
    await mount(tester);
    expect(visibleNumber(tester), '0123456789');

    container.read(withdrawalBankDraftProvider.notifier).clear();
    await tester.pump();

    expect(visibleNumber(tester), isEmpty);
    expect(service.resolveCalls, 1);
  });

  testWidgets('leaving and re-entering restores the draft number', (
    tester,
  ) async {
    service.listResponses = [_list([])];
    await makeContainer(tester);
    await mount(tester);

    container.read(withdrawalBankDraftProvider.notifier).selectBank(_gtb);
    await tester.enterText(accountField(), '0123456789');
    await tester.pump();

    await unmount(tester);
    await mount(tester);

    expect(visibleNumber(tester), '0123456789');
    expect(draft().accountNumber, '0123456789');
    expect(find.text('Guaranty Trust Bank'), findsOneWidget);
  });

  testWidgets('reaching the cap then removing an account shows an empty form', (
    tester,
  ) async {
    service.listResponses = [
      _list(['1111111111'], maxAllowed: 2),
      _list(['1111111111', '0123456789'], maxAllowed: 2),
      _list(['1111111111'], maxAllowed: 2),
    ];
    service.addResponse = NotifierState.done(
      AddWithdrawalBankAccountData.fromJson(
        _accountJson('account-1', '0123456789'),
      ),
    );
    service.deleteResponse = NotifierState.done(
      DeleteWithdrawalBankAccountData.fromJson({
        'bankAccountId': 'account-1',
        'status': 'deleted',
      }),
    );
    await makeContainer(tester);
    await seedResolvedDraft('0123456789');
    await mount(tester);
    expect(visibleNumber(tester), '0123456789');

    await tapSave(tester);
    expect(find.text('Account limit reached'), findsOneWidget);
    expect(accountField(), findsNothing);

    final remove = find.byTooltip('Remove account').last;
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pump(const Duration(milliseconds: 300));
    // Let the confirmation sheet finish sliding in.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(DestructiveButton, 'Remove account'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Account limit reached'), findsNothing);
    expect(visibleNumber(tester), isEmpty);
    expect(draft().accountNumber, isEmpty);
  });
}
