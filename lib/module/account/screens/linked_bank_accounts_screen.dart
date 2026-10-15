part of 'account_screens.dart';

/// Live withdrawal bank accounts.
///
/// Replaces the former preview, which showed fabricated accounts. Nothing here
/// is rendered unless the server returned it: an empty or failed load shows an
/// empty state or an inline retry, never a sample row.
extension _LinkedBankAccountsScreen on _AccountPageState {
  Widget _linkedBankAccountsScreen() {
    final catalogueState = ref.watch(bankCatalogueProvider);
    final accountsState = ref.watch(withdrawalBankAccountsProvider);

    // Both are needed before anything can be added, so they load together.
    if (catalogueState.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(bankCatalogueProvider.notifier).load);
    }
    if (accountsState.status == ServiceStatus.idle) {
      Future<void>.microtask(
        ref.read(withdrawalBankAccountsProvider.notifier).load,
      );
    }

    final accounts = accountsState.data;
    final canAddAnother = accounts?.canAddAnother ?? false;

    return AppScaffold(
      title: 'Linked banks',
      activeSection: AppSection.account,
      onBack: back,
      onSectionSelected: goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          Text(
            'Bank accounts you can withdraw to. The account name must match '
            'your profile name.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),

          if (accountsState.isLoading && accounts == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (accountsState.isError && accounts == null)
            ApiStateCard(
              title: 'Could not load your accounts',
              message: accountsState.message ?? 'Please check your connection.',
              tone: ApiStateTone.error,
              actionLabel: 'Retry',
              onAction: ref.read(withdrawalBankAccountsProvider.notifier).load,
            )
          else if (accounts != null && accounts.bankAccounts.isEmpty)
            const ApiStateCard(
              title: 'No withdrawal accounts yet',
              message:
                  'Add a bank account to withdraw your savings. We check the '
                  'account name against your profile before saving it.',
              tone: ApiStateTone.info,
            )
          else if (accounts != null)
            ...accounts.bankAccounts.map(_savedAccountTile),

          if (accountsState.isError && accounts != null) ...[
            const SizedBox(height: 12),
            ApiStateCard(
              title: 'Showing your last known accounts',
              message: accountsState.message ?? 'Refresh to try again.',
              tone: ApiStateTone.warning,
              actionLabel: 'Retry',
              onAction: ref.read(withdrawalBankAccountsProvider.notifier).load,
            ),
          ],

          const SizedBox(height: 20),

          if (accounts != null && !canAddAnother)
            ApiStateCard(
              title: 'Account limit reached',
              message:
                  'You can save up to ${accounts.maxAllowed ?? 0} withdrawal '
                  'accounts. Remove one to add another.',
              tone: ApiStateTone.blocked,
            )
          else if (accounts != null)
            _addWithdrawalAccountForm(catalogueState),
        ],
      ),
    );
  }

  Widget _savedAccountTile(WithdrawalBankAccount account) {
    final deleting = ref
        .read(withdrawalBankAccountsProvider.notifier)
        .isDeleting;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(IconsaxPlusLinear.bank),
        title: Text(account.accountName),
        subtitle: Text('${account.bankName} · ${account.maskedAccountNumber}'),
        trailing: IconButton(
          icon: const Icon(IconsaxPlusLinear.trash),
          tooltip: 'Remove account',
          onPressed: deleting ? null : () => _confirmDeleteAccount(account),
        ),
      ),
    );
  }

  /// Deleting is only recoverable by adding the account again, so it is always
  /// confirmed and never applied optimistically.
  Future<void> _confirmDeleteAccount(WithdrawalBankAccount account) async {
    final confirmed = await AppConfirmSheet.show(
      context,
      title: 'Remove this account?',
      message:
          'You will no longer be able to withdraw to '
          '${account.bankName} ${account.maskedAccountNumber}. You can add it '
          'again later.',
      confirmLabel: 'Remove account',
      cancelLabel: 'Keep account',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final result = await ref
        .read(withdrawalBankAccountsProvider.notifier)
        .delete(account.bankAccountId);
    if (!mounted) return;

    if (result.isDone) {
      showSuccessMessage(result.message ?? 'Account removed.');
    } else if (result.isError) {
      showErrorMessage(result.message ?? 'We could not remove that account.');
    }
  }

  Widget _addWithdrawalAccountForm(
    NotifierState<BankCatalogueData> catalogueState,
  ) {
    return _WithdrawalAccountForm(
      catalogueState: catalogueState,
      onSave: _saveWithdrawalAccount,
    );
  }

  Future<void> _saveWithdrawalAccount() async {
    final result = await ref.read(withdrawalBankDraftProvider.notifier).save();
    if (!mounted) return;

    if (result.isDone) {
      showSuccessMessage(result.message ?? 'Withdrawal account saved.');
    } else if (result.isError) {
      showErrorMessage(result.message ?? 'We could not save that account.');
    }
  }
}

/// The add-account form owns its account-number controller so the visible
/// number is always the one in [withdrawalBankDraftProvider].
///
/// The draft outlives this widget (it survives navigation and the account cap
/// hiding the form), so the controller is seeded from it on mount and follows
/// it afterwards: a successful save or a cleared draft empties the field
/// instead of leaving a number that Check/Save would no longer use.
class _WithdrawalAccountForm extends ConsumerStatefulWidget {
  const _WithdrawalAccountForm({
    required this.catalogueState,
    required this.onSave,
  });

  final NotifierState<BankCatalogueData> catalogueState;

  /// Saves the draft; the navigator reports the outcome.
  final Future<void> Function() onSave;

  @override
  ConsumerState<_WithdrawalAccountForm> createState() =>
      _WithdrawalAccountFormState();
}

class _WithdrawalAccountFormState
    extends ConsumerState<_WithdrawalAccountForm> {
  late final TextEditingController _accountController;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(
      text: ref.read(withdrawalBankDraftProvider).data?.accountNumber ?? '',
    );
    // Only writes the controller: syncing never starts a resolution.
    ref.listenManual(withdrawalBankDraftProvider, (previous, next) {
      final number = next.data?.accountNumber ?? '';
      // Typing already matches the draft, so the cursor is left alone.
      if (_accountController.text != number) {
        _accountController.value = TextEditingValue(
          text: number,
          selection: TextSelection.collapsed(offset: number.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _accountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = widget.catalogueState;
    final draftState = ref.watch(withdrawalBankDraftProvider);
    final draft = draftState.data ?? const WithdrawalBankDraft();
    final busy = draftState.isLoading;
    final banks = catalogueState.data?.banks ?? const <BankData>[];

    if (catalogueState.isError && banks.isEmpty) {
      return ApiStateCard(
        title: 'Could not load banks',
        message: catalogueState.message ?? 'Please check your connection.',
        tone: ApiStateTone.error,
        actionLabel: 'Retry',
        onAction: ref.read(bankCatalogueProvider.notifier).load,
      );
    }

    final resolution = draft.resolution;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add a bank account',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        FormDropdown<BankData>(
          label: 'Bank',
          value: draft.bank,
          items: banks
              .map(
                (bank) => DropdownMenuItem(value: bank, child: Text(bank.name)),
              )
              .toList(growable: false),
          onChanged: busy
              ? null
              : (bank) {
                  if (bank != null) {
                    ref
                        .read(withdrawalBankDraftProvider.notifier)
                        .selectBank(bank);
                  }
                },
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Account number',
          hintText: '10 digits',
          controller: _accountController,
          keyboardType: TextInputType.number,
          enabled: !busy,
          inputFormatters: bankAccountNumberInputFormatters(),
          onChanged: (value) => ref
              .read(withdrawalBankDraftProvider.notifier)
              .setAccountNumber(value),
        ),
        const SizedBox(height: 14),

        if (resolution != null) ...[
          ApiStateCard(
            title: resolution.isNameMatch
                ? 'Account confirmed'
                : 'Name does not match',
            // The numeric match score is deliberately not shown: it is an
            // internal threshold, not something a customer can act on.
            message: resolution.isNameMatch
                ? 'This account belongs to ${resolution.accountName}.'
                : 'This account belongs to ${resolution.accountName}, which '
                      'does not match your profile name. You can only '
                      'withdraw to an account in your own name.',
            tone: resolution.isNameMatch
                ? ApiStateTone.success
                : ApiStateTone.blocked,
          ),
          const SizedBox(height: 14),
        ],

        if (draftState.isError && draftState.message != null) ...[
          ApiStateCard(
            title: 'Could not continue',
            message: draftState.message!,
            tone: ApiStateTone.error,
          ),
          const SizedBox(height: 14),
        ],

        PrimaryButton(
          label: 'Check account',
          isLoading: busy && !draft.canSave,
          onPressed: busy
              ? null
              : ref.read(withdrawalBankDraftProvider.notifier).resolve,
        ),
        const SizedBox(height: 10),
        PrimaryButton(
          label: 'Save account',
          isLoading: busy && draft.canSave,
          // Enabled only when the server confirmed this exact account.
          onPressed: (busy || !draft.canSave) ? null : widget.onSave,
        ),
      ],
    );
  }
}
