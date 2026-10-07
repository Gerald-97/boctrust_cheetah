import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_money.dart';
import '../model/core_submission_models.dart';
import '../model/interbank_models.dart';
import '../model/intrabank_models.dart';
import '../provider/core_account_providers.dart';
import '../provider/core_payments_providers.dart';
import '../service/core_transfer_service.dart';
import '../service/transaction_authorizer.dart';

/// Integer Kobo as display Naira (`'150000'` → `₦1,500.00`).
String nairaFromKobo(String kobo) =>
    formatApiAmount(koboToNaira(kobo), currency: 'NGN') ?? '';

/// `•••• 7777` for a number the customer typed.
String maskNumber(String number) =>
    number.length <= 4 ? number : '•••• ${number.substring(number.length - 4)}';

const _noBalance = InvalidMoney(
  "We couldn't load this account's balance, so the amount can't be "
  'checked yet. Tap Retry below.',
);

/// Shown when Core finds no account for a name check.
const kAccountNotFound =
    "We couldn't find this account. Check the bank and number.";

/// The account name at [bankCode], or null when Core cannot confirm it.
Future<String?> lookUpAccountName(
  WidgetRef ref, {
  required String bankCode,
  required String accountNumber,
}) async =>
    (await ref
            .read(coreTransferServiceProvider)
            .nameEnquiry(bankCode: bankCode, accountNumber: accountNumber))
        .data
        ?.name;

/// [text] checked against an available [balance] (a decimal Naira string).
/// Kobo for transfers, or two-decimal Naira when [naira] (bills). A missing
/// balance is explained, never reported as "exceeds your limit".
MoneyInput amountWithin(String text, String? balance, {bool naira = false}) {
  final max = balanceToKobo(balance);
  if (max == null) return _noBalance;
  return naira
      ? parseNairaAmount(text, maxKobo: max)
      : parseNairaToKobo(text, maxKobo: max);
}

/// Whether an optional narration fits Core's limit.
bool narrationFits(String text) => text.trim().length <= kNarrationMaxLength;

/// The amount error to show under a field, or null while empty or valid.
String? amountError(String text, MoneyInput amount) => text.trim().isEmpty
    ? null
    : switch (amount) {
        InvalidMoney(:final message) => message,
        ValidMoney() => null,
      };

/// Runs the transaction authorizer; true only when the customer authorized.
Future<bool> authorizeCoreTransaction(
  BuildContext context,
  WidgetRef ref,
  TransactionSummary summary,
) async {
  final authorized = await ref
      .read(transactionAuthorizerProvider)
      .authorize(context, summary);
  if (!authorized && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This transaction was not authorized.')),
    );
  }
  return authorized;
}

/// An outcome to show in place of the one read from Core's reply, e.g. an
/// interbank transfer's checked status.
typedef CoreResultOverride = ({
  BocStatusKind kind,
  String title,
  String message,
});

/// What happened to a submitted transfer or payment, on the shared
/// [TransactionResultView]. Success is shown only for an approved reply;
/// unknown never offers a resend.
class CoreSubmissionResult extends StatelessWidget {
  const CoreSubmissionResult({
    required this.inFlight,
    required this.outcome,
    required this.noun,
    required this.onDone,
    required this.onChangeDetails,
    this.amount,
    this.details = const [],
    this.acceptedExtra = const [],
    this.trustResponseCode = true,
    this.codeConfirmsCompletion = false,
    this.acceptedOverride,
    super.key,
  });

  final bool inFlight;
  final CoreSubmissionOutcome? outcome;

  /// "Transfer" or "Payment".
  final String noun;
  final VoidCallback onDone;
  final VoidCallback onChangeDetails;

  /// Formatted Naira.
  final String? amount;

  /// What was sent, e.g. biller and plan; the reference is added here.
  final List<({String label, String value})> details;

  /// Shown under an accepted result (status check, save beneficiary).
  final List<Widget> acceptedExtra;

  /// Whether an approved `responseCode` means the money moved. False where
  /// a separate status read is authoritative (interbank).
  final bool trustResponseCode;

  /// Whether this endpoint's `00` is recorded as final (bill payments).
  /// Transfers show success only from a live status query.
  final bool codeConfirmsCompletion;

  /// A later, authoritative status that replaces the reply's own.
  final CoreResultOverride? acceptedOverride;

  @override
  Widget build(BuildContext context) {
    if (inFlight) {
      return ApiLoadingSection(label: 'Sending your ${noun.toLowerCase()}');
    }
    final lower = noun.toLowerCase();
    switch (outcome) {
      case AcceptedSubmission(:final ack):
        final reference = ack.displayReference;
        final CoreResultOverride(:kind, :title, :message) =
            acceptedOverride ??
            switch (trustResponseCode
                ? ack.outcomeFor(codeConfirmsCompletion: codeConfirmsCompletion)
                : CoreAckOutcome.processing) {
              CoreAckOutcome.succeeded => (
                kind: BocStatusKind.success,
                title: '$noun successful',
                message: 'Your balance will update shortly.',
              ),
              CoreAckOutcome.failed => (
                kind: BocStatusKind.failed,
                title: '$noun failed',
                message:
                    'This $lower did not go through. If your balance '
                    'changed, contact support with the reference below.',
              ),
              CoreAckOutcome.processing => (
                kind: BocStatusKind.pending,
                title: '$noun processing',
                message:
                    "We're waiting for confirmation. Check your balance "
                    'shortly before trying again.',
              ),
              CoreAckOutcome.unknown => (
                kind: BocStatusKind.pending,
                title: '$noun not confirmed',
                message:
                    "We couldn't confirm this $lower. Check your balance "
                    'before trying again.',
              ),
            };
        return TransactionResultView(
          kind: kind,
          title: title,
          message: message,
          amount: amount,
          details: [
            ...details,
            if (reference != null) (label: 'Reference', value: reference),
          ],
          extra: acceptedExtra,
          primaryLabel: 'Done',
          onPrimary: onDone,
        );
      case RejectedSubmission(:final message):
        return TransactionResultView(
          kind: BocStatusKind.failed,
          title: '$noun declined',
          message: '$message No money has left your account.',
          amount: amount,
          details: details,
          primaryLabel: 'Change details',
          onPrimary: onChangeDetails,
          secondaryLabel: 'Close',
          onSecondary: onDone,
        );
      case final UnknownSubmission unknown:
        return TransactionResultView(
          kind: BocStatusKind.pending,
          title: '$noun not confirmed',
          message: unknown.message,
          amount: amount,
          details: details,
          primaryLabel: 'Done',
          onPrimary: onDone,
        );
      case null:
        return const SizedBox.shrink();
    }
  }
}

/// A searchable bank list in a bottom sheet.
Future<CommercialBank?> showBankPicker(
  BuildContext context,
  List<CommercialBank> banks,
) => showModalBottomSheet<CommercialBank>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _BankPicker(banks: banks),
);

class _BankPicker extends StatefulWidget {
  const _BankPicker({required this.banks});
  final List<CommercialBank> banks;

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final bank in widget.banks)
        if (query.isEmpty || bank.name.toLowerCase().contains(query)) bank,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(BocSpace.gutter),
              child: AppTextField(
                label: 'Search banks',
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(child: Text('No bank matches your search.'))
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(matches[index].name),
                        onTap: () => Navigator.of(context).pop(matches[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A heading for one step of a flow.
class FlowHeading extends StatelessWidget {
  const FlowHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BocSpace.md),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

/// Inline field error text.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: BocSpace.xxs),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

/// The review summary, laid out like the receipt card: what is being done,
/// the amount large, then the details.
class CoreReviewCard extends StatelessWidget {
  const CoreReviewCard({
    required this.caption,
    required this.amount,
    required this.rows,
    super.key,
  });

  /// e.g. "You're sending" or "You're paying".
  final String caption;

  /// Formatted Naira, e.g. `₦100.00`.
  final String amount;
  final List<({String label, String value})> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        BocSpace.lg,
        BocSpace.lg,
        BocSpace.lg,
        BocSpace.md,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(BocRadius.md),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: colors.border)
            : null,
      ),
      child: Column(
        children: [
          Text(caption, style: theme.textTheme.bodyMedium),
          const SizedBox(height: BocSpace.xs),
          BocMoneyText(amount, style: theme.textTheme.displaySmall),
          const SizedBox(height: BocSpace.md),
          Divider(height: 1, color: colors.border),
          const SizedBox(height: BocSpace.xs),
          TransactionDetailRows(rows: rows),
        ],
      ),
    );
  }
}

/// The search box used above long lists, as on the Payments grid.
class CoreSearchField extends StatelessWidget {
  const CoreSearchField({
    required this.hintText,
    required this.onChanged,
    super.key,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: BocSpace.md),
    child: TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(IconsaxPlusLinear.search_normal_1),
      ),
    ),
  );
}

/// The receiving-bank row: a settings-style tile that opens [showBankPicker].
class BankSelectorTile extends StatelessWidget {
  const BankSelectorTile({
    required this.bank,
    required this.banks,
    required this.loading,
    required this.onSelected,
    super.key,
  });

  final CommercialBank? bank;
  final List<CommercialBank> banks;
  final bool loading;
  final ValueChanged<CommercialBank> onSelected;

  @override
  Widget build(BuildContext context) => SettingsGroup(
    padding: EdgeInsets.zero,
    children: [
      SettingsTile(
        icon: IconsaxPlusLinear.bank,
        title: bank?.name ?? 'Choose a bank',
        subtitle: loading && banks.isEmpty
            ? 'Loading banks…'
            : bank == null
            ? 'The receiving bank'
            : 'Tap to change',
        onTap: banks.isEmpty
            ? null
            : () async {
                final picked = await showBankPicker(context, banks);
                if (picked != null) onSelected(picked);
              },
      ),
    ],
  );
}

/// The amount (or a fixed price), the available balance and an optional
/// narration, shared by every transfer and payment form.
class CoreAmountFields extends ConsumerWidget {
  const CoreAmountFields({
    required this.input,
    required this.available,
    required this.onChanged,
    this.amount,
    this.fixedAmount,
    this.narration,
    super.key,
  }) : assert((amount == null) != (fixedAmount == null));

  /// The checked amount, from [amountWithin].
  final MoneyInput input;

  /// The source account's balance, a decimal Naira string.
  final String? available;
  final VoidCallback onChanged;

  /// The typed amount; null when the plan has a [fixedAmount].
  final TextEditingController? amount;

  /// A two-decimal Naira price the customer cannot change.
  final String? fixedAmount;
  final TextEditingController? narration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fixed = fixedAmount;
    final amount = this.amount;
    final message = amountError(fixed ?? amount!.text, input);
    final narration = this.narration;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (amount != null)
          AppTextField(
            label: 'Amount (₦)',
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
          )
        else
          BocSummaryGrid(
            items: [
              (
                label: 'Amount',
                value: formatApiAmount(fixed, currency: 'NGN') ?? fixed!,
              ),
            ],
          ),
        if (message != null) FieldError(message),
        const SizedBox(height: BocSpace.xxs),
        Row(
          children: [
            Expanded(
              child: Text(
                'Available: ${formatApiAmount(available, currency: 'NGN') ?? 'unavailable'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            // Every balance shown here comes from the account list.
            if (available == null)
              BocTextButton(
                label: 'Retry',
                onPressed: ref.read(customerBankAccountsProvider.notifier).load,
              ),
          ],
        ),
        if (narration != null) ...[
          const SizedBox(height: BocSpace.sm),
          AppTextField(
            label: 'Narration (optional)',
            controller: narration,
            onChanged: (_) => onChanged(),
            validator: (_) => narrationFits(narration.text)
                ? null
                : 'Use $kNarrationMaxLength characters or fewer.',
            autovalidateMode: AutovalidateMode.always,
          ),
        ],
      ],
    );
  }
}

/// Saves [body] as a beneficiary once; repeat taps while saving are ignored.
class SaveBeneficiaryButton extends ConsumerStatefulWidget {
  const SaveBeneficiaryButton({required this.body, super.key});

  /// From `bankBeneficiaryRequest` or `billBeneficiaryRequest`.
  final Map<String, Object?> body;

  @override
  ConsumerState<SaveBeneficiaryButton> createState() =>
      _SaveBeneficiaryButtonState();
}

class _SaveBeneficiaryButtonState extends ConsumerState<SaveBeneficiaryButton> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final error = await ref
        .read(beneficiariesProvider.notifier)
        .add(widget.body);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Beneficiary saved.')));
  }

  @override
  Widget build(BuildContext context) => SecondaryButton(
    label: _saving ? 'Saving…' : 'Save as beneficiary',
    onPressed: _saving ? null : _save,
  );
}
