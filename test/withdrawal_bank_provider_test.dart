import 'dart:async';

import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/account/model/withdrawal_bank_models.dart';
import 'package:boctrust_savings_loan/module/account/provider/withdrawal_bank_providers.dart';
import 'package:boctrust_savings_loan/module/account/service/withdrawal_bank_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _gtb = BankData(name: 'Guaranty Trust Bank', code: '058');
const _access = BankData(name: 'Access Bank', code: '044');

Map<String, Object?> _accountJson({
  String id = 'account-1',
  String number = '0123456789',
}) => {
  'bankAccountId': id,
  'bankCode': '058',
  'bankName': 'Guaranty Trust Bank',
  'accountNumber': number,
  'accountName': 'Ada Example',
};

ResolveWithdrawalBankAccountData _resolution({
  String bankCode = '058',
  String accountNumber = '0123456789',
  bool isNameMatch = true,
}) => ResolveWithdrawalBankAccountData.fromJson({
  'bankCode': bankCode,
  'bankName': 'Guaranty Trust Bank',
  'accountNumber': accountNumber,
  'accountName': 'Ada Example',
  'nameMatchScore': '0.96',
  'minimumRequiredScore': '0.80',
  'isNameMatch': isNameMatch,
});

class _FakeService implements WithdrawalBankService {
  List<NotifierState<WithdrawalBankAccountListData>> listResponses = [];
  NotifierState<ResolveWithdrawalBankAccountData>? resolveResponse;
  Completer<void>? resolveGate;
  NotifierState<AddWithdrawalBankAccountData>? addResponse;
  NotifierState<DeleteWithdrawalBankAccountData>? deleteResponse;

  int listCalls = 0;
  int addCalls = 0;
  AddWithdrawalBankAccountRequest? lastAdd;

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
    await resolveGate?.future;
    return resolveResponse!;
  }

  @override
  Future<NotifierState<AddWithdrawalBankAccountData>> addAccount(
    AddWithdrawalBankAccountRequest request,
  ) async {
    addCalls++;
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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [withdrawalBankServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => service = _FakeService());

  test('1. load retains stale list data during a failing refresh', () async {
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': [_accountJson()],
          'maxAllowed': 2,
        }),
      ),
      const NotifierState<WithdrawalBankAccountListData>.error('offline'),
    ];
    final container = makeContainer();
    final notifier = container.read(withdrawalBankAccountsProvider.notifier);

    await notifier.load();
    await notifier.load();

    final state = container.read(withdrawalBankAccountsProvider);
    expect(state.isError, isTrue);
    expect(state.data!.bankAccounts, hasLength(1));
  });

  test('2. changing bank or account number clears the resolution', () async {
    service.resolveResponse = NotifierState.done(_resolution());
    final container = makeContainer();
    final drafts = container.read(withdrawalBankDraftProvider.notifier);

    Future<void> establishResolution() async {
      drafts.selectBank(_gtb);
      drafts.setAccountNumber('0123456789');
      await drafts.resolve();
      expect(
        container.read(withdrawalBankDraftProvider).data!.resolution,
        isNotNull,
        reason: 'the test is only meaningful with a resolution to clear',
      );
    }

    // Switching bank invalidates it: the result described another account.
    await establishResolution();
    drafts.selectBank(_access);
    expect(
      container.read(withdrawalBankDraftProvider).data!.resolution,
      isNull,
    );

    // So does editing the account number.
    await establishResolution();
    drafts.setAccountNumber('9999999999');
    expect(
      container.read(withdrawalBankDraftProvider).data!.resolution,
      isNull,
    );
    expect(container.read(withdrawalBankDraftProvider).data!.canSave, isFalse);
  });

  test('3. resolve stores a result only when it matches the draft', () async {
    service.resolveResponse = NotifierState.done(_resolution());
    final container = makeContainer();
    final drafts = container.read(withdrawalBankDraftProvider.notifier);

    drafts.selectBank(_gtb);
    drafts.setAccountNumber('0123456789');
    await drafts.resolve();

    final draft = container.read(withdrawalBankDraftProvider).data!;
    expect(draft.resolution, isNotNull);
    expect(draft.canSave, isTrue);
  });

  test('4. save is blocked without a name match, and at the cap', () async {
    service.resolveResponse = NotifierState.done(
      _resolution(isNameMatch: false),
    );
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': <Object?>[],
          'maxAllowed': 2,
        }),
      ),
    ];
    final container = makeContainer();
    await container.read(withdrawalBankAccountsProvider.notifier).load();
    final drafts = container.read(withdrawalBankDraftProvider.notifier);

    drafts.selectBank(_gtb);
    drafts.setAccountNumber('0123456789');
    await drafts.resolve();

    expect(container.read(withdrawalBankDraftProvider).data!.canSave, isFalse);
    var result = await drafts.save();
    expect(result.isError, isTrue);
    expect(service.addCalls, 0, reason: 'a mismatch must never be saved');

    // Now a match, but the server cap is already reached.
    service.resolveResponse = NotifierState.done(_resolution());
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': [_accountJson()],
          'maxAllowed': 1,
        }),
      ),
    ];
    await container.read(withdrawalBankAccountsProvider.notifier).load();
    await drafts.resolve();
    expect(container.read(withdrawalBankDraftProvider).data!.canSave, isTrue);

    result = await drafts.save();
    expect(result.isError, isTrue);
    expect(service.addCalls, 0, reason: 'the server cap must be respected');
  });

  test('5. a successful save reloads the list and clears the draft', () async {
    service.resolveResponse = NotifierState.done(_resolution());
    service.addResponse = NotifierState.done(
      AddWithdrawalBankAccountData.fromJson(_accountJson()),
    );
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': <Object?>[],
          'maxAllowed': 2,
        }),
      ),
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': [_accountJson()],
          'maxAllowed': 2,
        }),
      ),
    ];
    final container = makeContainer();
    await container.read(withdrawalBankAccountsProvider.notifier).load();
    final drafts = container.read(withdrawalBankDraftProvider.notifier);

    drafts.selectBank(_gtb);
    drafts.setAccountNumber('0123456789');
    await drafts.resolve();
    final result = await drafts.save();

    expect(result.isDone, isTrue);
    // Saved with the values the server resolved, not the raw form fields.
    expect(service.lastAdd!.accountNumber, '0123456789');
    expect(service.lastAdd!.bankCode, '058');
    expect(service.listCalls, 2, reason: 'the list is reloaded after saving');
    final draft = container.read(withdrawalBankDraftProvider).data!;
    expect(draft.bank, isNull);
    expect(draft.accountNumber, isEmpty);
    expect(draft.resolution, isNull);
  });

  test('6. a successful delete reloads the list', () async {
    service.deleteResponse = NotifierState.done(
      DeleteWithdrawalBankAccountData.fromJson({
        'bankAccountId': 'account-1',
        'status': 'deleted',
      }),
    );
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': [_accountJson()],
          'maxAllowed': 2,
        }),
      ),
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': <Object?>[],
          'maxAllowed': 2,
        }),
      ),
    ];
    final container = makeContainer();
    final notifier = container.read(withdrawalBankAccountsProvider.notifier);
    await notifier.load();

    final result = await notifier.delete('account-1');

    expect(result.isDone, isTrue);
    expect(
      container.read(withdrawalBankAccountsProvider).data!.bankAccounts,
      isEmpty,
    );
  });

  test('6b. a failed delete keeps the row', () async {
    service.deleteResponse =
        const NotifierState<DeleteWithdrawalBankAccountData>.error(
          'Could not delete.',
        );
    service.listResponses = [
      NotifierState.done(
        WithdrawalBankAccountListData.fromJson({
          'bankAccounts': [_accountJson()],
          'maxAllowed': 2,
        }),
      ),
    ];
    final container = makeContainer();
    final notifier = container.read(withdrawalBankAccountsProvider.notifier);
    await notifier.load();

    final result = await notifier.delete('account-1');

    expect(result.isError, isTrue);
    expect(
      container.read(withdrawalBankAccountsProvider).data!.bankAccounts,
      hasLength(1),
      reason: 'deletion is only recoverable by re-adding, so never optimistic',
    );
  });

  test('7. a stale resolve cannot overwrite a newer account number', () async {
    service.resolveGate = Completer<void>();
    service.resolveResponse = NotifierState.done(
      _resolution(accountNumber: '0123456789'),
    );
    final container = makeContainer();
    final drafts = container.read(withdrawalBankDraftProvider.notifier);

    drafts.selectBank(_gtb);
    drafts.setAccountNumber('0123456789');
    final inFlight = drafts.resolve();

    // The user keeps typing while the request is in flight.
    drafts.setAccountNumber('5555555555');
    service.resolveGate!.complete();
    await inFlight;

    final draft = container.read(withdrawalBankDraftProvider).data!;
    expect(draft.accountNumber, '5555555555');
    expect(
      draft.resolution,
      isNull,
      reason: 'a result for a different account must not be attached',
    );
    expect(draft.canSave, isFalse);
  });
}
