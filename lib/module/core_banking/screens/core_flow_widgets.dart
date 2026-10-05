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
import '../provider/core_payments_providers.dart';
import '../service/transaction_authorizer.dart';

/// Integer Kobo as display Naira (`'150000'` → `₦1,500.00`).
String nairaFromKobo(String kobo) =>
    formatApiAmount(koboToNaira(kobo), currency: 'NGN') ?? '';

/// `•••• 7777` for a number the customer typed.
String maskNumber(String number) =>
    number.length <= 4 ? number : '•••• ${number.substring(number.length - 4)}';

const _noBalance = InvalidMoney(
  "We couldn't load this account's balance, so the amount can't be "
  'checked yet. Pull down to refresh or try again shortly.',
);

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

/// What happened to a submitted transfer or payment. Accepted is shown as
/// submitted, never completed; unknown never offers a resend.
class CoreSubmissionResult extends StatelessWidget {
  const CoreSubmissionResult({
    required this.inFlight,
    required this.outcome,
    required this.noun,
    required this.onDone,
    required this.onChangeDetails,
    this.acceptedExtra = const [],
    this.acceptedStatus,
    super.key,
  });

  final bool inFlight;
  final CoreSubmissionOutcome? outcome;

  /// "Transfer" or "Payment".
  final String noun;
  final VoidCallback onDone;
  final VoidCallback onChangeDetails;

  /// Shown under an accepted result (status check, save beneficiary).
  final List<Widget> acceptedExtra;

  /// A later, authoritative status (interbank) that replaces the
  /// "submitted" card, so the two never contradict each other.
  final Widget? acceptedStatus;

  @override
  Widget build(BuildContext context) {
    if (inFlight) {
      return ApiLoadingSection(label: 'Sending your ${noun.toLowerCase()}');
    }
    final children = switch (outcome) {
      AcceptedSubmission(:final ack) => [
        ?acceptedStatus,
        if (acceptedStatus == null)
          ApiStateCard(
            title: '$noun submitted',
            message: [
              if (ack.reference != null) 'Reference ${ack.reference}.',
              if (ack.status != null) 'Status: ${ack.status}.',
              'Your balance will update shortly.',
            ].join(' '),
            tone: ApiStateTone.info,
          ),
        ...acceptedExtra,
        const SizedBox(height: BocSpace.md),
        PrimaryButton(label: 'Done', onPressed: onDone),
      ],
      RejectedSubmission(:final message) => [
        ApiStateCard(
          title: '$noun declined',
          message: message,
          tone: ApiStateTone.error,
        ),
        const SizedBox(height: BocSpace.md),
        PrimaryButton(label: 'Change details', onPressed: onChangeDetails),
      ],
      final UnknownSubmission unknown => [
        ApiStateCard(
          title: '$noun not confirmed',
          message: unknown.message,
          tone: ApiStateTone.warning,
        ),
        const SizedBox(height: BocSpace.md),
        PrimaryButton(label: 'Done', onPressed: onDone),
      ],
      null => const <Widget>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
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
class CoreAmountFields extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        Text(
          'Available: ${formatApiAmount(available, currency: 'NGN') ?? 'unavailable'}',
          style: Theme.of(context).textTheme.bodySmall,
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
