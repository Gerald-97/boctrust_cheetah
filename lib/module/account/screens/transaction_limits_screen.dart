import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../app_flow/flow_page.dart';
import '../../../utils/input_formatters.dart';
import '../../core_banking/model/core_money.dart';
import '../../core_banking/provider/core_transfer_attempt_provider.dart';
import '../../core_banking/screens/core_flow_widgets.dart';
import '../../core_banking/screens/transaction_pin_sheet.dart';
import '../../core_banking/screens/transfer_otp_sheet.dart';
import '../../core_banking/service/transaction_authorizer.dart';
import '../model/transaction_limit_models.dart';
import '../model/transaction_limit_update_models.dart';
import '../provider/transaction_limit_provider.dart';
import '../provider/transaction_limit_update_provider.dart';
import '../provider/user_providers.dart';

/// The three limits a customer can change.
enum _LimitField {
  single('Single transfer'),
  daily('Daily transfers'),
  bill('Single bill payment');

  const _LimitField(this.label);
  final String label;

  TransactionLimit of(TransactionLimits limits) => switch (this) {
    single => limits.singleTransfer,
    daily => limits.dailyTransfer,
    bill => limits.singleBillPayment,
  };
}

/// An entry's Kobo as the Naira decimal Core takes.
String? _naira(String? kobo) => kobo == null ? null : koboToNaira(kobo);

/// One field's checked entry: the changed value in Kobo (converted to Naira
/// when sent), or why it can't be sent. Unchanged and empty fields have
/// neither.
typedef _Entry = ({String? kobo, String? error});

/// The customer's effective transfer and bill-payment limits. Viewing needs
/// only `transactionLimitsView`; changing them is `transactionLimitsEdit`.
class TransactionLimitsScreen extends ConsumerStatefulWidget {
  const TransactionLimitsScreen({super.key});

  @override
  ConsumerState<TransactionLimitsScreen> createState() =>
      _TransactionLimitsScreenState();
}

class _TransactionLimitsScreenState
    extends FlowPageState<TransactionLimitsScreen> {
  final _fields = {
    for (final field in _LimitField.values) field: TextEditingController(),
  };
  bool _editing = false;
  bool _reviewing = false;

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// [field]'s entry against the current limits. The Swagger states no unit
  /// for limit inputs; they are sent in Naira, and editing
  /// stays staging-only until staging confirms it.
  _Entry _entry(_LimitField field, TransactionLimits limits) {
    final text = _fields[field]!.text.trim();
    if (text.isEmpty) return (kobo: null, error: null);
    final limit = field.of(limits);
    final parsed = parseNairaToKobo(text, maxKobo: '99999999999999');
    if (parsed is! ValidMoney) {
      return (kobo: null, error: 'Enter a valid amount.');
    }
    final kobo = parsed.minorUnits;
    final ceiling = balanceToKobo(limit.business);
    if (ceiling != null && BigInt.parse(kobo) > BigInt.parse(ceiling)) {
      return (
        kobo: null,
        error: 'This is above your tier maximum of ${nairaFromKobo(ceiling)}.',
      );
    }
    return kobo == balanceToKobo(limit.effective)
        ? (kobo: null, error: null)
        : (kobo: kobo, error: null);
  }

  void _startEditing(TransactionLimits limits) {
    for (final field in _LimitField.values) {
      final kobo = balanceToKobo(field.of(limits).effective);
      final text = kobo == null
          ? ''
          : koboToNaira(kobo).replaceFirst(RegExp(r'\.00$'), '');
      _fields[field]!.value = ThousandsAmountFormatter().formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(text: text),
      );
    }
    setState(() {
      _editing = true;
      _reviewing = false;
    });
  }

  /// Initiate, then the PIN sheet (Core sends the OTP), the OTP sheet, and
  /// one finalize. The PIN and OTP live only in local variables.
  Future<void> _confirm(
    TransactionLimitDraft draft,
    List<(String, String)> lines,
  ) async {
    final notifier = ref.read(transactionLimitUpdateProvider.notifier);
    LimitUpdatePhase phase() => ref.read(transactionLimitUpdateProvider).phase;
    await notifier.start(draft);
    String? error;
    while (phase() == LimitUpdatePhase.awaitingPin) {
      if (!mounted) return notifier.reset();
      final pin = await collectCoreTransactionPin(
        context,
        TransactionSummary(
          title: 'Change your limits',
          amountDisplay: 'Limit change',
          lines: lines,
        ),
        errorMessage: error,
        confirmLabel: 'Verify PIN',
      );
      if (pin == null || !mounted) return notifier.reset();
      final step = await notifier.verifyPin(pin);
      error = step is CheckRetry ? step.message : null;
    }
    if (phase() == LimitUpdatePhase.awaitingOtp) {
      if (!mounted) return notifier.reset();
      final verified = await collectTransferOtp(
        context,
        verifyCode: notifier.verifyOtp,
        resendCode: notifier.resendOtp,
      );
      // Closed without a verified code, possibly mid-verify: drop the change
      // (a late reply is ignored) so it can't block the next one.
      if (!verified && phase() != LimitUpdatePhase.failed) {
        return notifier.reset();
      }
    }
    if (phase() == LimitUpdatePhase.readyToFinalize) await notifier.finalize();
    if (mounted) {
      setState(() {
        _editing = false;
        _reviewing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.transactionLimitsView),
        )
        .isAvailable) {
      return popScope(
        unavailablePage(
          const UnavailableDestination(
            title: 'Transaction limits',
            heading: 'Unavailable',
            message: 'Transaction limits are not available yet.',
            section: AppSection.account,
            capability: FeatureCapability.transactionLimitsView,
          ),
        ),
      );
    }
    final limits = ref.watch(transactionLimitsProvider);
    return popScope(
      AppScaffold(
        title: 'Transaction limits',
        activeSection: AppSection.account,
        onBack: back,
        onSectionSelected: goSection,
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(transactionLimitsProvider.future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              BocSpace.xxs,
              BocSpace.gutter,
              BocSpace.lg,
            ).clearOfNav(context),
            children: [
              ..._updateResult(),
              switch (limits) {
                AsyncData(:final value) when value.data != null && _editing =>
                  _editor(value.data!),
                AsyncData(:final value) when value.data != null => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _limits(value.data!),
                    ..._changeAction(value.data!),
                  ],
                ),
                // Tier 0 has no limits to show until BVN and liveness. Core's
                // tier can lag the User Service's, so a customer the User
                // Service already verified sees Core's own reason instead.
                AsyncData(:final value)
                    when value.statusCode == 403 &&
                        ref.watch(userTierProvider).data?.currentTier == 0 =>
                  ApiStateCard(
                    title: 'Verify your identity',
                    message:
                        'Verify your BVN and complete a liveness check to '
                        'see your limits.',
                    tone: ApiStateTone.info,
                    actionLabel: 'Verify now',
                    onAction: () => go(AppRoutes.tier1Bvn),
                  ),
                AsyncData(:final value) => ApiStateCard(
                  title: 'Limits unavailable',
                  message: value.message ?? "We couldn't load your limits.",
                  tone: ApiStateTone.error,
                  actionLabel: 'Retry',
                  onAction: () => ref.invalidate(transactionLimitsProvider),
                ),
                _ => const ApiLoadingSection(label: 'Loading your limits'),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _limits(TransactionLimits limits) {
    String money(String? naira) =>
        formatApiAmount(naira, currency: 'NGN') ?? 'Unavailable';
    return BocSummaryGrid(
      items: [
        (label: 'Tier', value: 'Tier ${limits.tier}'),
        for (final (label, limit) in [
          ('Single transfer', limits.singleTransfer),
          ('Daily transfers', limits.dailyTransfer),
          ('Single bill payment', limits.singleBillPayment),
        ])
          (label: label, value: money(limit.effective)),
      ],
    );
  }

  List<Widget> _updateResult() {
    final update = ref.watch(transactionLimitUpdateProvider);
    final card = switch (update.phase) {
      LimitUpdatePhase.updated => const ApiStateCard(
        title: 'Limits updated',
        message: 'Your limits were updated.',
        tone: ApiStateTone.info,
      ),
      LimitUpdatePhase.failed => ApiStateCard(
        title: 'Limits not changed',
        message: update.message ?? 'Your limits were not changed.',
        tone: ApiStateTone.error,
      ),
      LimitUpdatePhase.unknown => ApiStateCard(
        title: 'Change not confirmed',
        message: update.message ?? "We couldn't confirm the change.",
        tone: ApiStateTone.warning,
      ),
      _ => null,
    };
    return card == null
        ? const []
        : [card, const SizedBox(height: BocSpace.md)];
  }

  /// "Change limits", only under its own capability and never while a change
  /// is open or unresolved.
  List<Widget> _changeAction(TransactionLimits limits) {
    final phase = ref.watch(transactionLimitUpdateProvider).phase;
    final canEdit = ref
        .watch(
          featureAvailabilityProvider(FeatureCapability.transactionLimitsEdit),
        )
        .isAvailable;
    if (!canEdit ||
        !{
          LimitUpdatePhase.idle,
          LimitUpdatePhase.updated,
          LimitUpdatePhase.failed,
        }.contains(phase)) {
      return const [];
    }
    return [
      const SizedBox(height: BocSpace.lg),
      SecondaryButton(
        label: 'Change limits',
        onPressed: () => _startEditing(limits),
      ),
    ];
  }

  Widget _editor(TransactionLimits limits) {
    final entries = {
      for (final field in _LimitField.values) field: _entry(field, limits),
    };
    final changed = [
      for (final MapEntry(key: field, value: entry) in entries.entries)
        if (entry.kobo != null) (field, entry.kobo!),
    ];
    final valid = entries.values.every((e) => e.error == null);
    final lines = [
      for (final (field, kobo) in changed) (field.label, nairaFromKobo(kobo)),
    ];
    final draft = TransactionLimitDraft(
      singleTransferLimit: _naira(entries[_LimitField.single]!.kobo),
      dailyTransferLimit: _naira(entries[_LimitField.daily]!.kobo),
      singleBillPaymentLimit: _naira(entries[_LimitField.bill]!.kobo),
    );
    final busy =
        ref.watch(transactionLimitUpdateProvider).phase !=
            LimitUpdatePhase.idle &&
        !{
          LimitUpdatePhase.updated,
          LimitUpdatePhase.failed,
        }.contains(ref.watch(transactionLimitUpdateProvider).phase);
    if (_reviewing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BocSummaryGrid(
            items: [
              for (final (label, value) in lines) (label: label, value: value),
            ],
          ),
          const SizedBox(height: BocSpace.lg),
          PrimaryButton(
            label: 'Confirm changes',
            isLoading: busy,
            onPressed: () => _confirm(draft, lines),
          ),
          BocTextButton(
            label: 'Edit',
            onPressed: () => setState(() => _reviewing = false),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in _LimitField.values) ...[
          AppTextField(
            label: '${field.label} (₦)',
            controller: _fields[field]!,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [ThousandsAmountFormatter()],
            onChanged: (_) => setState(() {}),
          ),
          if (entries[field]!.error case final error?)
            FieldError(error)
          else if (balanceToKobo(field.of(limits).business) case final ceiling?)
            Text(
              'Tier maximum ${nairaFromKobo(ceiling)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: BocSpace.md),
        ],
        PrimaryButton(
          label: 'Review changes',
          onPressed: valid && changed.isNotEmpty
              ? () => setState(() => _reviewing = true)
              : null,
        ),
        BocTextButton(
          label: 'Cancel',
          onPressed: () => setState(() => _editing = false),
        ),
      ],
    );
  }
}
