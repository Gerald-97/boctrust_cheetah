part of '../app_flow/app_ui.dart';

/// A server-confirmed receipt on a ticket-shaped card. It takes a
/// [TransactionReceipt], which only exists for a successful server response,
/// so it can never present a pending or failed transaction as complete.
class BocReceiptCard extends StatelessWidget {
  const BocReceiptCard({required this.receipt, super.key});

  final TransactionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final completed = DateFormat(
      'd MMM y, h:mm a',
    ).format(receipt.completedAt.toLocal());
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 32),
          child: ClipPath(
            clipper: const _TicketEdgeClipper(),
            child: Container(
              width: double.infinity,
              color: colors.surface,
              padding: const EdgeInsets.fromLTRB(
                BocSpace.lg,
                48,
                BocSpace.lg,
                BocSpace.xl,
              ),
              child: Column(
                children: [
                  Text(
                    receipt.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: BocSpace.xs),
                  BocMoneyText(
                    receipt.amount,
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: BocSpace.xxs),
                  Text(
                    'Successful',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.successText,
                    ),
                  ),
                  const SizedBox(height: BocSpace.md),
                  Divider(color: colors.border),
                  const SizedBox(height: BocSpace.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Transaction details',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: BocSpace.xs),
                  TransactionDetailRows(
                    rows: [
                      ...receipt.details,
                      (label: 'Date', value: completed),
                      (label: 'Reference', value: receipt.reference),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.successContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(BocSpace.sm),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: colors.success,
              child: const Icon(Icons.check_rounded, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// Label/value rows for a transaction, values right-aligned.
class TransactionDetailRows extends StatelessWidget {
  const TransactionDetailRows({required this.rows, super.key});

  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: BocSpace.xs),
            child: MergeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.label, style: theme.textTheme.bodySmall),
                  const SizedBox(width: BocSpace.md),
                  Expanded(
                    child: SelectableText(
                      row.value,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Scalloped bottom edge of the receipt ticket.
class _TicketEdgeClipper extends CustomClipper<Path> {
  const _TicketEdgeClipper();

  @override
  Path getClip(Size size) {
    const radius = 7.0;
    final path = Path()
      ..moveTo(0, 16)
      ..quadraticBezierTo(0, 0, 16, 0)
      ..lineTo(size.width - 16, 0)
      ..quadraticBezierTo(size.width, 0, size.width, 16)
      ..lineTo(size.width, size.height - radius);
    final count = (size.width / (radius * 3)).floor();
    final step = size.width / count;
    for (var i = count; i > 0; i--) {
      final x = i * step;
      path
        ..lineTo(x, size.height - radius)
        ..arcToPoint(
          Offset(x - radius * 2, size.height - radius),
          radius: const Radius.circular(radius),
        );
    }
    return path
      ..lineTo(0, size.height - radius)
      ..close();
  }

  @override
  bool shouldReclip(_TicketEdgeClipper oldClipper) => false;
}

/// The outcome of a transfer or payment, shown in place inside its flow:
/// the animated status badge, the amount, a plain-language message, the
/// details and what to do next. It renders only what it is given; the flow
/// decides the outcome from Core's reply.
class TransactionResultView extends StatelessWidget {
  const TransactionResultView({
    required this.kind,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.amount,
    this.details = const [],
    this.secondaryLabel,
    this.onSecondary,
    this.extra = const [],
    super.key,
  });

  final BocStatusKind kind;
  final String title;
  final String message;

  /// Formatted Naira, e.g. `₦1,000.00`.
  final String? amount;
  final List<({String label, String value})> details;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// Follow-up actions under the details, e.g. Check status.
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final amount = this.amount;
    final secondaryLabel = this.secondaryLabel;
    final accent = switch (kind) {
      BocStatusKind.success => colors.successText,
      BocStatusKind.pending => colors.warningText,
      BocStatusKind.failed => colors.errorText,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: BocSpace.md),
        Center(child: BocStatusMark(kind: kind)),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(color: accent),
        ),
        if (amount != null) ...[
          const SizedBox(height: BocSpace.xs),
          Center(
            child: BocMoneyText(amount, style: theme.textTheme.displaySmall),
          ),
        ],
        const SizedBox(height: BocSpace.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (details.isNotEmpty) ...[
          const SizedBox(height: BocSpace.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: BocSpace.lg,
              vertical: BocSpace.sm,
            ),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BocRadius.md),
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: colors.border)
                  : null,
            ),
            child: TransactionDetailRows(rows: details),
          ),
        ],
        ...extra,
        const SizedBox(height: BocSpace.lg),
        PrimaryButton(label: primaryLabel, onPressed: onPrimary),
        if (secondaryLabel != null) ...[
          const SizedBox(height: BocSpace.xs),
          BocTextButton(label: secondaryLabel, onPressed: onSecondary),
        ],
      ],
    );
  }
}
