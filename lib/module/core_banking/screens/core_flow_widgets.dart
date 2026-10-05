import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../model/core_money.dart';
import '../model/core_submission_models.dart';
import '../model/interbank_models.dart';
import '../service/transaction_authorizer.dart';

/// Integer Kobo as display Naira (`'150000'` → `₦1,500.00`).
String nairaFromKobo(String kobo) =>
    formatApiAmount(koboToNaira(kobo), currency: 'NGN') ?? '';

/// `•••• 7777` for a number the customer typed.
String maskNumber(String number) =>
    number.length <= 4 ? number : '•••• ${number.substring(number.length - 4)}';

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

  @override
  Widget build(BuildContext context) {
    if (inFlight) {
      return ApiLoadingSection(label: 'Sending your ${noun.toLowerCase()}');
    }
    final children = switch (outcome) {
      AcceptedSubmission(:final ack) => [
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
