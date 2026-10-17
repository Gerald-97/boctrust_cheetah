import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/response_handler.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../model/customer_bank_account_models.dart';
import '../provider/account_freeze_provider.dart';
import '../provider/core_account_providers.dart';
import '../service/transaction_authorizer.dart';
import 'transaction_pin_sheet.dart';

/// The last four digits of an account number, for lists and sheets.
String maskedAccountNumber(String accountNumber) {
  final tail = accountNumber.length > 4
      ? accountNumber.substring(accountNumber.length - 4)
      : accountNumber;
  return '••••$tail';
}

CustomerBankAccount? _accountFor(WidgetRef ref, String accountNumber) {
  final accounts = ref.read(customerBankAccountsProvider).data?.accounts;
  if (accounts == null) return null;
  for (final account in accounts) {
    if (account.accountNumber == accountNumber) return account;
  }
  return null;
}

TransactionSummary _summary(
  WidgetRef ref,
  String accountNumber,
  String action,
) {
  final name = _accountFor(ref, accountNumber)?.productName;
  return TransactionSummary(
    title: name == null ? '$action account' : '$action $name',
    amountDisplay: maskedAccountNumber(accountNumber),
  );
}

/// Explains the freeze, then asks for the PIN and freezes [accountNumber].
/// The PIN is held only for the one request; a rejected PIN is asked for
/// again with the controller's message.
Future<void> openFreezeFlow(
  BuildContext context,
  WidgetRef ref,
  String accountNumber,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Freeze this account?'),
      content: const Text(
        'Money cannot leave a frozen account. You can still see its balance '
        'and history, and you can unfreeze it any time.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final provider = accountFreezeProvider(accountNumber);
  final summary = _summary(ref, accountNumber, 'Freeze');
  String? error;
  while (true) {
    final pin = await collectCoreTransactionPin(
      context,
      summary,
      errorMessage: error,
      confirmLabel: 'Freeze account',
    );
    if (pin == null || !context.mounted) return;
    await ref.read(provider.notifier).freeze(pin);
    if (!context.mounted) return;
    final state = ref.read(provider);
    if (state.errorKind == AccountFreezeErrorKind.wrongCredentials) {
      error = state.message;
      continue;
    }
    if (state.message != null) {
      ResponseHandler.showError(state.message!);
    } else if (_accountFor(ref, accountNumber)?.status ==
        CoreAccountStatus.frozen) {
      ResponseHandler.showSuccess('Account frozen.');
    }
    return;
  }
}

/// Sends the unfreeze code, then asks for the PIN and the code and unfreezes
/// [accountNumber]. Opened from Security Center and from the Home banner. A
/// bank-frozen account ends with the controller's support message; cancelling
/// at any step sends nothing more.
Future<void> openUnfreezeFlow(
  BuildContext context,
  WidgetRef ref,
  String accountNumber,
) async {
  final provider = accountFreezeProvider(accountNumber);
  await ref.read(provider.notifier).sendOtp();
  if (!context.mounted) return;
  if (!_continueUnfreeze(ref, accountNumber)) return;
  final summary = _summary(ref, accountNumber, 'Unfreeze');
  String? error;
  while (true) {
    final pin = await collectCoreTransactionPin(
      context,
      summary,
      errorMessage: error,
      confirmLabel: 'Continue',
    );
    if (pin == null || !context.mounted) return;
    final code = await collectUnfreezeCode(context, accountNumber);
    if (!context.mounted) return;
    if (code == null) {
      final state = ref.read(provider);
      if (state.phase == AccountFreezePhase.bankFrozen) {
        ResponseHandler.showError(state.message!);
      }
      return;
    }
    await ref.read(provider.notifier).unfreeze(pin, code);
    if (!context.mounted) return;
    final state = ref.read(provider);
    if (state.errorKind == AccountFreezeErrorKind.wrongCredentials) {
      error = state.message;
      continue;
    }
    if (state.message != null) {
      ResponseHandler.showError(state.message!);
    } else if (_accountFor(ref, accountNumber)?.isActive ?? false) {
      ResponseHandler.showSuccess('Account unfrozen.');
    }
    return;
  }
}

/// Whether the code was sent and the PIN and code can be asked for. Otherwise
/// the reason is shown.
bool _continueUnfreeze(WidgetRef ref, String accountNumber) {
  final state = ref.read(accountFreezeProvider(accountNumber));
  if (state.phase == AccountFreezePhase.awaitingOtp) return true;
  if (state.message != null) {
    ResponseHandler.showError(state.message!);
  } else if (_accountFor(ref, accountNumber)?.isActive ?? false) {
    ResponseHandler.showInfo('This account is not frozen.');
  }
  return false;
}

/// Asks for the six-digit unfreeze code. Returns it as typed, or null when
/// the customer cancels or the bank turns out to have frozen the account.
/// The caller owns the string only for the one request.
Future<String?> collectUnfreezeCode(
  BuildContext context,
  String accountNumber,
) => AppActionSheet.show<String>(
  context: context,
  builder: (_) => UnfreezeCodeSheet(accountNumber: accountNumber),
);

const _codeLength = 6;

class UnfreezeCodeSheet extends ConsumerStatefulWidget {
  const UnfreezeCodeSheet({required this.accountNumber, super.key});

  final String accountNumber;

  @override
  ConsumerState<UnfreezeCodeSheet> createState() => _UnfreezeCodeSheetState();
}

class _UnfreezeCodeSheetState extends ConsumerState<UnfreezeCodeSheet> {
  final _controller = TextEditingController();
  bool _closing = false;
  String? _notice;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..clear()
      ..dispose();
    super.dispose();
  }

  bool get _complete =>
      !_closing && RegExp('^\\d{$_codeLength}\$').hasMatch(_controller.text);

  void _close([String? code]) {
    if (_closing) return;
    _closing = true;
    _controller.clear();
    Navigator.of(context).pop(code);
  }

  Future<void> _resend() async {
    final provider = accountFreezeProvider(widget.accountNumber);
    setState(() {
      _notice = null;
      _error = null;
    });
    await ref.read(provider.notifier).sendOtp();
    if (!mounted) return;
    final state = ref.read(provider);
    switch (state.phase) {
      case AccountFreezePhase.awaitingOtp:
        setState(() => _notice = 'We sent you a new code.');
      case AccountFreezePhase.bankFrozen:
        _close();
      default:
        setState(
          () => _error = state.message ?? 'We could not send a new code.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(accountFreezeProvider(widget.accountNumber));
    final expiresAt = state.otpExpiresAt;
    final message = _error ?? _notice;
    return AppActionSheet(
      key: const Key('unfreeze-code-sheet'),
      icon: IconsaxPlusLinear.message_text,
      title: 'Enter the code we sent you',
      subtitle: expiresAt == null
          ? 'Check your phone or email for a 6-digit code.'
          : 'Check your phone or email for a 6-digit code. It expires at '
                '${DateFormat('h:mm a').format(expiresAt.toLocal())}.',
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: 'Unfreeze account',
            onPressed: _complete ? () => _close(_controller.text) : null,
          ),
          const SizedBox(height: BocSpace.xs),
          BocTextButton(
            label: 'Send a new code',
            isLoading: state.phase == AccountFreezePhase.sendingOtp,
            onPressed: state.isBusy ? null : _resend,
          ),
          BocTextButton(label: 'Cancel', onPressed: _close),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PinInputField(
            pinLength: _codeLength,
            pinCtrl: _controller,
            autofocus: true,
            isActive: !_closing,
          ),
          if (message != null) ...[
            const SizedBox(height: BocSpace.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _error != null ? context.bocColors.errorText : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
