import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/account_freeze_models.dart';
import '../model/customer_bank_account_models.dart';
import '../service/core_account_service.dart';
import 'core_account_providers.dart';

enum AccountFreezePhase {
  idle,
  sendingOtp,
  awaitingOtp,
  submitting,

  /// The bank froze the account; only support can unfreeze it.
  bankFrozen,
  error,
}

enum AccountFreezeErrorKind {
  /// The PIN (or, on unfreeze, the PIN or code) was rejected.
  wrongCredentials,

  /// The request may or may not have been applied and the re-read failed.
  unconfirmed,

  /// The account is not one of the caller's.
  notFound,

  /// Core did not send the code.
  failed,
}

const kFreezeWrongPinMessage = 'That PIN is not correct.';
const kUnfreezeWrongCredentialsMessage = 'The PIN or code is not correct.';
const kFreezeBankFrozenMessage =
    'This account was frozen by the bank. Contact support to unfreeze it.';
const kFreezeUnconfirmedMessage = 'Account status could not be confirmed';
const kFreezeNotFoundMessage = 'We could not find this account.';
const kUnfreezeCodeFailedMessage = 'We could not send the code. Try again.';

/// Where one account's freeze or unfreeze stands. It never holds a PIN or
/// code.
class AccountFreezeState extends Equatable {
  const AccountFreezeState({
    this.phase = AccountFreezePhase.idle,
    this.otpExpiresAt,
    this.errorKind,
    this.message,
  });

  final AccountFreezePhase phase;

  /// When the unfreeze code expires, if Core said; kept through a wrong-code
  /// error so the customer can try the code again.
  final DateTime? otpExpiresAt;
  final AccountFreezeErrorKind? errorKind;

  /// A safe message to show for [AccountFreezePhase.error] and
  /// [AccountFreezePhase.bankFrozen].
  final String? message;

  bool get isBusy =>
      phase == AccountFreezePhase.sendingOtp ||
      phase == AccountFreezePhase.submitting;

  @override
  List<Object?> get props => [phase, otpExpiresAt, errorKind, message];
}

final accountFreezeProvider =
    NotifierProvider.family<
      AccountFreezeController,
      AccountFreezeState,
      String
    >(AccountFreezeController.new);

/// Who froze each account, from this session's freeze and unfreeze replies.
/// Core reads never say, so this is the only place the app can learn it.
/// A bank freeze seen as a `403` is recorded as [CoreFrozenBy.admin].
final accountFreezeMemoryProvider =
    NotifierProvider<AccountFreezeMemory, Map<String, CoreFrozenBy>>(
      AccountFreezeMemory.new,
    );

class AccountFreezeMemory extends Notifier<Map<String, CoreFrozenBy>> {
  @override
  Map<String, CoreFrozenBy> build() {
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != next) state = const {};
    });
    return const {};
  }

  void record(AccountFreezeResult result) {
    final by = result.frozenBy;
    if (result.status == CoreAccountStatus.frozen && by != null) {
      remember(result.accountNumber, by);
    } else if (result.status == CoreAccountStatus.active) {
      state = {...state}..remove(result.accountNumber);
    }
  }

  void remember(String accountNumber, CoreFrozenBy by) =>
      state = {...state, accountNumber: by};
}

/// Runs one freeze, unfreeze code request or unfreeze at a time for one
/// account. A POST is never repeated: after a success, a `409` or an unclear
/// answer, the account is read again and Core's status decides what is shown.
class AccountFreezeController extends Notifier<AccountFreezeState>
    with StaleResultGuard<AccountFreezeState> {
  AccountFreezeController(this.accountNumber);

  final String accountNumber;

  @override
  AccountFreezeState build() {
    trackDisposal();
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != next) clear();
    });
    return const AccountFreezeState();
  }

  CoreAccountService get _service => ref.read(coreAccountServiceProvider);
  AccountFreezeMemory get _memory =>
      ref.read(accountFreezeMemoryProvider.notifier);

  /// Freezes the account. [transactionPin] is used for this request only.
  Future<void> freeze(String transactionPin) async {
    if (state.isBusy) return;
    final token = beginRequest();
    state = const AccountFreezeState(phase: AccountFreezePhase.submitting);
    final outcome = await _service.freezeAccount(accountNumber, transactionPin);
    if (!isCurrent(token)) return;
    switch (outcome) {
      case FreezeSucceeded(:final result):
        _memory.record(result);
        await _confirm(token);
      case FreezeWrongCredentials():
        _fail(AccountFreezeErrorKind.wrongCredentials, kFreezeWrongPinMessage);
      case FreezeBankFrozen():
        _bankFrozen();
      case FreezeNotFound():
        await _notFound(token);
      case FreezeConflict() || FreezeUncertain():
        await _confirm(token);
    }
  }

  /// Asks Core to send the unfreeze code. Calling it again resends.
  Future<void> sendOtp() async {
    if (state.isBusy) return;
    final token = beginRequest();
    state = const AccountFreezeState(phase: AccountFreezePhase.sendingOtp);
    final outcome = await _service.sendUnfreezeOtp(accountNumber);
    if (!isCurrent(token)) return;
    switch (outcome) {
      case FreezeSucceeded(:final result) when result.otpSent:
        state = AccountFreezeState(
          phase: AccountFreezePhase.awaitingOtp,
          otpExpiresAt: result.otpExpiresAt,
        );
      case FreezeSucceeded() || FreezeWrongCredentials():
        _fail(AccountFreezeErrorKind.failed, kUnfreezeCodeFailedMessage);
      case FreezeBankFrozen():
        _bankFrozen();
      case FreezeNotFound():
        await _notFound(token);
      case FreezeConflict() || FreezeUncertain():
        await _confirm(token);
    }
  }

  /// Unfreezes the account. [transactionPin] and [otpCode] are used for this
  /// request only.
  Future<void> unfreeze(String transactionPin, String otpCode) async {
    if (state.isBusy) return;
    final token = beginRequest();
    final otpExpiresAt = state.otpExpiresAt;
    state = AccountFreezeState(
      phase: AccountFreezePhase.submitting,
      otpExpiresAt: otpExpiresAt,
    );
    final outcome = await _service.unfreezeAccount(
      accountNumber,
      transactionPin,
      otpCode,
    );
    if (!isCurrent(token)) return;
    switch (outcome) {
      case FreezeSucceeded(:final result):
        _memory.record(result);
        await _confirm(token);
      case FreezeWrongCredentials():
        _fail(
          AccountFreezeErrorKind.wrongCredentials,
          kUnfreezeWrongCredentialsMessage,
          otpExpiresAt: otpExpiresAt,
        );
      case FreezeBankFrozen():
        _bankFrozen();
      case FreezeNotFound():
        await _notFound(token);
      case FreezeConflict() || FreezeUncertain():
        await _confirm(token);
    }
  }

  /// Reads the account again without sending anything, for the action shown
  /// beside "Account status could not be confirmed".
  Future<void> refreshStatus() async {
    if (state.isBusy) return;
    final token = beginRequest();
    state = const AccountFreezeState(phase: AccountFreezePhase.submitting);
    await _confirm(token);
  }

  /// Drops everything, including a late reply, on a session change.
  void clear() {
    beginRequest();
    state = const AccountFreezeState();
  }

  void _fail(
    AccountFreezeErrorKind kind,
    String message, {
    DateTime? otpExpiresAt,
  }) {
    state = AccountFreezeState(
      phase: AccountFreezePhase.error,
      errorKind: kind,
      message: message,
      otpExpiresAt: otpExpiresAt,
    );
  }

  void _bankFrozen() {
    _memory.remember(accountNumber, CoreFrozenBy.admin);
    state = const AccountFreezeState(
      phase: AccountFreezePhase.bankFrozen,
      message: kFreezeBankFrozenMessage,
    );
  }

  Future<void> _notFound(int token) async {
    await ref.read(customerBankAccountsProvider.notifier).load();
    if (!isCurrent(token)) return;
    _fail(AccountFreezeErrorKind.notFound, kFreezeNotFoundMessage);
  }

  /// Re-reads the account; Core's status then decides what the screen shows.
  Future<void> _confirm(int token) async {
    final accounts = ref.read(customerBankAccountsProvider.notifier);
    var confirmed = false;
    if (ref.read(customerBankAccountsProvider).data != null) {
      confirmed = await accounts.refreshAccount(accountNumber);
    }
    if (!confirmed && isCurrent(token)) {
      final loaded = await accounts.load();
      confirmed = loaded.data != null && !loaded.isError;
    }
    if (!isCurrent(token)) return;
    if (confirmed) {
      state = const AccountFreezeState();
    } else {
      _fail(AccountFreezeErrorKind.unconfirmed, kFreezeUnconfirmedMessage);
    }
  }
}
