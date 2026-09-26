part of '../../app_flow/app_flow_navigator.dart';

/// Transaction detail. Shows only a record the server returned; a receipt
/// card appears only when the server supplied a completed receipt.
extension TransactionFlowScreens on AppFlowNavigatorState {
  Widget _transactionDetailScreen() {
    final id = widget.routeArguments.entityId;
    final history = ref.watch(transactionHistoryProvider);
    final record = history.data
        ?.where((candidate) => candidate.id == id)
        .firstOrNull;
    final receipt = record?.receipt;
    return AppScaffold(
      title: 'Transaction details',
      activeSection: AppSection.payments,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.all(BocSpace.gutter),
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
