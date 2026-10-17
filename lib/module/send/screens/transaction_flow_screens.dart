part of 'send_screens.dart';

/// Transaction detail. Shows only a record the server returned; a receipt
/// card appears only when the server supplied a completed receipt.
extension TransactionFlowScreens on FlowPageState {
  /// The Flex account's transactions, as Core returns them.
  Widget _transactionHistoryScreen() {
    final accounts = ref.watch(customerBankAccountsProvider);
    if (accounts.status == ServiceStatus.idle) {
      Future<void>.microtask(
        ref.read(customerBankAccountsProvider.notifier).ensureLoaded,
      );
    }
    final accountNumber = accounts.data?.flexAccount?.accountNumber;
    return AppScaffold(
      title: 'Transaction history',
      activeSection: AppSection.payments,
      onBack: back,
      onSectionSelected: goSection,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(BocSpace.gutter).clearOfNav(context),
        children: [
          if (accountNumber != null)
            CoreAccountHistoryList(accountNumber: accountNumber)
          else if (accounts.isError)
            ApiStateCard(
              title: 'Transaction history unavailable',
              message: accounts.message ?? 'We could not load your accounts.',
              tone: ApiStateTone.error,
              actionLabel: 'Retry',
              onAction: ref.read(customerBankAccountsProvider.notifier).load,
            )
          else if (accounts.isDone)
            const ApiStateCard(
              title: 'No Flex account',
              message: 'You have no Boc Flex account yet.',
              tone: ApiStateTone.info,
            )
          else
            const ApiLoadingSection(label: 'Loading your transactions'),
        ],
      ),
    );
  }

  Widget _transactionDetailScreen() {
    final id = routeArguments.entityId;
    final history = ref.watch(transactionHistoryProvider);
    final record = history.data
        ?.where((candidate) => candidate.id == id)
        .firstOrNull;
    final receipt = record?.receipt;
    return AppScaffold(
      title: 'Transaction details',
      activeSection: AppSection.payments,
      onBack: back,
      onSectionSelected: goSection,
      body: ListView(
        padding: const EdgeInsets.all(BocSpace.gutter).clearOfNav(context),
        children: [
          if (record == null)
            ApiStateCard(
              title: 'Transaction details are unavailable',
              message:
                  history.message ??
                  'This transaction cannot be displayed yet.',
              tone: ApiStateTone.blocked,
            )
          else if (receipt != null)
            BocReceiptCard(receipt: receipt)
          else
            _TransactionStatusPanel(record: record),
        ],
      ),
    );
  }
}

/// A non-receipt view of a record that is pending, failed or reversed, or
/// successful without a server receipt.
class _TransactionStatusPanel extends StatelessWidget {
  const _TransactionStatusPanel({required this.record});

  final TransactionRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final (label, color) = switch (record.status) {
      TransactionStatus.pending => ('Pending', colors.warningText),
      TransactionStatus.successful => ('Successful', colors.successText),
      TransactionStatus.failed => ('Failed', colors.errorText),
      TransactionStatus.reversed => ('Reversed', colors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.all(BocSpace.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
      ),
      child: Column(
        children: [
          Text(
            record.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BocSpace.xs),
          BocMoneyText(record.amount, style: theme.textTheme.displaySmall),
          const SizedBox(height: BocSpace.xxs),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          const SizedBox(height: BocSpace.md),
          TransactionDetailRows(
            rows: [
              (
                label: 'Date',
                value: DateFormat(
                  'd MMM y, h:mm a',
                ).format(record.occurredAt.toLocal()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
