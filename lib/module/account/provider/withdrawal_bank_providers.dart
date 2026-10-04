import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../model/withdrawal_bank_models.dart';
import '../service/withdrawal_bank_service.dart';

final bankCatalogueProvider =
    NotifierProvider<BankCatalogueNotifier, NotifierState<BankCatalogueData>>(
      BankCatalogueNotifier.new,
    );

class BankCatalogueNotifier extends Notifier<NotifierState<BankCatalogueData>>
    with StaleResultGuard<NotifierState<BankCatalogueData>> {
  @override
  NotifierState<BankCatalogueData> build() {
    trackDisposal();
    return const NotifierState.idle();
  }

  Future<NotifierState<BankCatalogueData>> load() async {
    final token = beginRequest();
    state = NotifierState.loading(data: state.data);
    final result = await ref.read(withdrawalBankServiceProvider).getBanks();
    if (!isCurrent(token)) return result;
    state = result.isError && result.data == null && state.data != null
        ? NotifierState.error(
            result.message ?? 'Unable to load the list of banks.',
            data: state.data,
            statusCode: result.statusCode,
          )
        : result;
    return state;
  }

  void clear() {
    beginRequest();
    state = const NotifierState.idle();
  }
}

final withdrawalBankAccountsProvider =
    NotifierProvider<
      WithdrawalBankAccountsNotifier,
      NotifierState<WithdrawalBankAccountListData>
    >(WithdrawalBankAccountsNotifier.new);

class WithdrawalBankAccountsNotifier
    extends Notifier<NotifierState<WithdrawalBankAccountListData>>
    with StaleResultGuard<NotifierState<WithdrawalBankAccountListData>> {
  @override
  NotifierState<WithdrawalBankAccountListData> build() {
    trackDisposal();
    return const NotifierState.idle();
  }

  bool _deleting = false;

  /// Keeps the previously loaded list visible during a refresh, so the screen
  /// never flashes an empty state that would read as "no saved accounts".
  Future<NotifierState<WithdrawalBankAccountListData>> load() async {
    final token = beginRequest();
    state = NotifierState.loading(data: state.data);
    final result = await ref.read(withdrawalBankServiceProvider).listAccounts();
    if (!isCurrent(token)) return result;
    state = result.isError && result.data == null && state.data != null
        ? NotifierState.error(
            result.message ?? 'Unable to load your saved accounts.',
            data: state.data,
            statusCode: result.statusCode,
          )
        : result;
    return state;
  }

  /// Deletes server-side, then reloads.
  ///
  /// Never optimistic: removing a withdrawal destination is only recoverable by
  /// adding it again, so the row stays until the server confirms.
  Future<NotifierState<DeleteWithdrawalBankAccountData>> delete(
    String bankAccountId,
  ) async {
    if (_deleting) {
      return const NotifierState<DeleteWithdrawalBankAccountData>.idle();
    }
    _deleting = true;
    try {
      final result = await ref
          .read(withdrawalBankServiceProvider)
          .deleteAccount(bankAccountId);
      if (result.isDone) {
        await load();
        ref
            .read(withdrawalBankDraftProvider.notifier)
            .clearIfAccountRemoved(bankAccountId);
      }
      return result;
    } finally {
      _deleting = false;
    }
  }

  bool get isDeleting => _deleting;

  void clear() {
    beginRequest();
    state = const NotifierState.idle();
  }
}

/// The account the user is entering, and its latest resolution.
class WithdrawalBankDraft extends Equatable {
  const WithdrawalBankDraft({
    this.bank,
    this.accountNumber = '',
    this.resolution,
    this.savedAccountId,
  });

  final BankData? bank;
  final String accountNumber;

  /// Only ever the resolution for exactly this bank and account number.
  final ResolveWithdrawalBankAccountData? resolution;

  /// Set after a successful save, so a delete of that account can clear this.
  final String? savedAccountId;

  WithdrawalBankDraft copyWith({
    BankData? bank,
    String? accountNumber,
    ResolveWithdrawalBankAccountData? resolution,
    String? savedAccountId,
    bool clearResolution = false,
  }) => WithdrawalBankDraft(
    bank: bank ?? this.bank,
    accountNumber: accountNumber ?? this.accountNumber,
    resolution: clearResolution ? null : (resolution ?? this.resolution),
    savedAccountId: savedAccountId ?? this.savedAccountId,
  );

  /// True only when the resolution still describes what is on screen and the
  /// server said the name matches.
  bool get canSave {
    final selected = bank;
    final result = resolution;
    if (selected == null || result == null) return false;
    return result.isNameMatch &&
        result.matches(
          bankCode: selected.code,
          accountNumber: accountNumber.trim(),
        );
  }

  @override
  List<Object?> get props => [bank, accountNumber, resolution, savedAccountId];
}

final withdrawalBankDraftProvider =
    NotifierProvider<
      WithdrawalBankDraftNotifier,
      NotifierState<WithdrawalBankDraft>
    >(WithdrawalBankDraftNotifier.new);

class WithdrawalBankDraftNotifier
    extends Notifier<NotifierState<WithdrawalBankDraft>>
    with StaleResultGuard<NotifierState<WithdrawalBankDraft>> {
  @override
  NotifierState<WithdrawalBankDraft> build() {
    trackDisposal();
    return const NotifierState.idle(data: WithdrawalBankDraft());
  }

  bool _inFlight = false;

  WithdrawalBankDraft get _draft => state.data ?? const WithdrawalBankDraft();

  /// Changing the bank invalidates any resolution: it described a different
  /// account.
  void selectBank(BankData bank) {
    final draft = _draft;
    if (draft.bank?.code == bank.code) return;
    state = NotifierState.done(
      draft.copyWith(bank: bank, clearResolution: true),
    );
  }

  void setAccountNumber(String accountNumber) {
    final draft = _draft;
    if (draft.accountNumber == accountNumber) return;
    state = NotifierState.done(
      draft.copyWith(accountNumber: accountNumber, clearResolution: true),
    );
  }

  Future<void> resolve() async {
    if (_inFlight) return;
    final draft = _draft;
    final bank = draft.bank;
    if (bank == null) {
      state = NotifierState.error('Select a bank first.', data: draft);
      return;
    }

    final ResolveWithdrawalBankAccountRequest request;
    try {
      request = ResolveWithdrawalBankAccountRequest(
        bankCode: bank.code,
        bankName: bank.name,
        accountNumber: draft.accountNumber,
      );
    } on FormatException catch (error) {
      state = NotifierState.error(error.message, data: draft);
      return;
    }

    _inFlight = true;
    final token = beginRequest();
    try {
      state = NotifierState.loading(data: draft);
      final result = await ref
          .read(withdrawalBankServiceProvider)
          .resolveAccount(request);
      if (!isCurrent(token)) return;

      final data = result.data;
      // The user may have edited the form while this was in flight. A result
      // for a different account must never be attached to what is on screen.
      final current = _draft;
      final describesCurrentDraft =
          data != null &&
          data.matches(
            bankCode: current.bank?.code ?? '',
            accountNumber: current.accountNumber.trim(),
          );

      if (result.isDone && describesCurrentDraft) {
        state = NotifierState.done(
          current.copyWith(resolution: data),
          message: result.message,
        );
        return;
      }

      state = result.isDone
          ? NotifierState.done(current)
          : NotifierState.error(
              result.message ?? 'We could not check that account.',
              data: current.copyWith(clearResolution: true),
              statusCode: result.statusCode,
            );
    } finally {
      _inFlight = false;
    }
  }

  /// Saves only what the server has confirmed.
  Future<NotifierState<AddWithdrawalBankAccountData>> save() async {
    if (_inFlight) {
      return const NotifierState<AddWithdrawalBankAccountData>.idle();
    }
    final draft = _draft;
    final bank = draft.bank;
    final resolution = draft.resolution;
    if (bank == null || resolution == null || !draft.canSave) {
      const message =
          'Check the account details before saving. The account name must '
          'match your profile.';
      state = NotifierState.error(message, data: draft);
      return const NotifierState<AddWithdrawalBankAccountData>.error(message);
    }

    final accounts = ref.read(withdrawalBankAccountsProvider).data;
    if (accounts != null && !accounts.canAddAnother) {
      const message = 'You have reached the maximum number of saved accounts.';
      state = NotifierState.error(message, data: draft);
      return const NotifierState<AddWithdrawalBankAccountData>.error(message);
    }

    _inFlight = true;
    final token = beginRequest();
    try {
      state = NotifierState.loading(data: draft);
      // The exact values the server resolved, never the raw form fields.
      final result = await ref
          .read(withdrawalBankServiceProvider)
          .addAccount(
            AddWithdrawalBankAccountRequest(
              bankCode: resolution.bankCode,
              bankName: resolution.bankName,
              accountNumber: resolution.accountNumber,
            ),
          );
      if (!isCurrent(token)) return result;

      if (result.isDone) {
        await ref.read(withdrawalBankAccountsProvider.notifier).load();
        if (!isCurrent(token)) return result;
        state = const NotifierState.idle(data: WithdrawalBankDraft());
        return result;
      }

      state = NotifierState.error(
        result.message ?? 'We could not save that account.',
        data: draft,
        statusCode: result.statusCode,
      );
      return result;
    } finally {
      _inFlight = false;
    }
  }

  void clearIfAccountRemoved(String bankAccountId) {
    if (_draft.savedAccountId == bankAccountId) clear();
  }

  void clear() {
    beginRequest();
    _inFlight = false;
    state = const NotifierState.idle(data: WithdrawalBankDraft());
  }
}
