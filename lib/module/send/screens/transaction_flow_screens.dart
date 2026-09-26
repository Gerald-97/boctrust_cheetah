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

enum _TransferStep { recipient, amount, review, pin, result }

/// Recipient → amount → review → PIN → result. The result is drawn only from
/// the submission provider: a server receipt shows the receipt card; an
/// error shows a failure with no reference; anything unconfirmed is pending.
class _TransferFlow extends ConsumerStatefulWidget {
  const _TransferFlow({required this.onExit});

  final VoidCallback onExit;

  @override
  ConsumerState<_TransferFlow> createState() => _TransferFlowState();
}

class _TransferFlowState extends ConsumerState<_TransferFlow> {
  _TransferStep _step = _TransferStep.recipient;
  final _account = TextEditingController();
  final _bank = TextEditingController();
  final _amount = TextEditingController();
  final _narration = TextEditingController();
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    for (final controller in [_account, _bank, _amount, _pin]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final controller in [_account, _bank, _amount, _narration, _pin]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _valid => switch (_step) {
    _TransferStep.recipient =>
      RegExp(r'^\d{10}$').hasMatch(_account.text.trim()) &&
          _bank.text.trim().isNotEmpty,
    _TransferStep.amount =>
      (num.tryParse(_amount.text.replaceAll(',', '')) ?? 0) > 0,
    _TransferStep.review => true,
    _TransferStep.pin => RegExp(r'^\d{4}$').hasMatch(_pin.text),
    _TransferStep.result => true,
  };

  void _back() {
    switch (_step) {
      case _TransferStep.recipient:
      case _TransferStep.result:
        widget.onExit();
      case _TransferStep.amount:
        setState(() => _step = _TransferStep.recipient);
      case _TransferStep.review:
        setState(() => _step = _TransferStep.amount);
      case _TransferStep.pin:
        _pin.clear();
        setState(() => _step = _TransferStep.review);
    }
  }

  Future<void> _next() async {
    switch (_step) {
      case _TransferStep.recipient:
        setState(() => _step = _TransferStep.amount);
      case _TransferStep.amount:
        setState(() => _step = _TransferStep.review);
      case _TransferStep.review:
        setState(() => _step = _TransferStep.pin);
      case _TransferStep.pin:
        final request = TransferRequest(
          accountNumber: _account.text.trim(),
          bankName: _bank.text.trim(),
          amount: _amount.text.replaceAll(',', ''),
          narration: _narration.text.trim().isEmpty
              ? null
              : _narration.text.trim(),
          pin: _pin.text,
        );
        _pin.clear();
        await ref.read(transferSubmissionProvider.notifier).submit(request);
        if (mounted) setState(() => _step = _TransferStep.result);
      case _TransferStep.result:
        widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _TransferStep.result) return _result(context);
    final theme = Theme.of(context);
    final submitting = ref.watch(transferSubmissionProvider).isLoading;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !submitting) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: Padding(
            padding: const EdgeInsets.only(left: BocSpace.xs),
            child: BocBackButton(onPressed: submitting ? () {} : _back),
          ),
          leadingWidth: BocSpace.minTouch + BocSpace.md,
          title: Text(
            _step == _TransferStep.pin ? "Confirm it's you" : 'Send money',
          ),
        ),
        body: SafeArea(
          top: false,
          child: ResponsiveContent(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(BocSpace.gutter),
                    children: _body(theme),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    BocSpace.gutter,
                    0,
                    BocSpace.gutter,
                    BocSpace.md,
                  ),
                  child: PrimaryButton(
                    label: _step == _TransferStep.pin
                        ? 'Send money'
                        : 'Continue',
                    isLoading: submitting,
                    onPressed: _valid ? _next : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(ThemeData theme) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: BocSpace.md),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleLarge),
      ),
    );
    switch (_step) {
      case _TransferStep.recipient:
        return [
          heading('Who are you sending to?'),
          AppTextField(
            label: 'Account number',
            controller: _account,
            hintText: '10 digits',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: BocSpace.md),
          AppTextField(label: 'Bank name', controller: _bank),
        ];
      case _TransferStep.amount:
        return [
          heading('How much?'),
          AppTextField(
            label: 'Amount',
            controller: _amount,
            hintText: '₦0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: BocSpace.md),
          AppTextField(label: 'Narration (optional)', controller: _narration),
        ];
      case _TransferStep.review:
        return [
          heading('Review your transfer'),
          BocSummaryGrid(
            items: [
              (label: 'To', value: _account.text.trim()),
              (label: 'Bank', value: _bank.text.trim()),
              (label: 'Amount', value: '₦${_amount.text.trim()}'),
              if (_narration.text.trim().isNotEmpty)
                (label: 'Narration', value: _narration.text.trim()),
            ],
          ),
          const SizedBox(height: BocSpace.sm),
          Text(
            'Any fee is confirmed by the bank before the transfer completes.',
            style: theme.textTheme.bodySmall,
          ),
        ];
      case _TransferStep.pin:
        return [
          heading('Enter your transaction PIN'),
          Text(
            'Sending ₦${_amount.text.trim()} to ${_account.text.trim()}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: BocSpace.lg),
          PinInputField(
            pinLength: 4,
            obscureText: true,
            autofocus: true,
            pinCtrl: _pin,
          ),
        ];
      case _TransferStep.result:
        return const [];
    }
  }

  Widget _result(BuildContext context) {
    final submission = ref.watch(transferSubmissionProvider);
    final receipt = submission.data;
    if (submission.isDone && receipt != null) {
      return Scaffold(
        body: SafeArea(
          child: ResponsiveContent(
            child: ListView(
              padding: const EdgeInsets.all(BocSpace.gutter),
              children: [
                BocReceiptCard(receipt: receipt),
                const SizedBox(height: BocSpace.lg),
                PrimaryButton(label: 'Done', onPressed: widget.onExit),
              ],
            ),
          ),
        ),
      );
    }
    if (submission.isError) {
      return BocStatusScreen(
        kind: BocStatusKind.failed,
        title: 'Transfer failed',
        message:
            submission.message ??
            'Your transfer did not go through. No money '
                'has left your account.',
        primaryLabel: 'Try again',
        onPrimary: () => setState(() => _step = _TransferStep.review),
        secondaryLabel: 'Close',
        onSecondary: widget.onExit,
      );
    }
    return BocStatusScreen(
      kind: BocStatusKind.pending,
      title: 'Transfer pending',
      message:
          'We have not received a final result yet. Check your transaction '
          'history before trying again.',
      primaryLabel: 'Close',
      onPrimary: widget.onExit,
    );
  }
}
