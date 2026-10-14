import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/theme.dart';
import '../../../utils/input_formatters.dart';
import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../../core_banking/model/core_money.dart';
import '../../home/provider/home_provider.dart';
import '../provider/savings_plan_action_provider.dart';

/// The largest top-up the form accepts (in Kobo); Core enforces the real one.
const _maxTopUpKobo = '100000000000';

/// Tops up [planId] from Boc Flex. The sheet stays open on a failure so the
/// customer can correct the amount, and ends on the outcome.
class SavingsPlanTopUpSheet extends ConsumerStatefulWidget {
  const SavingsPlanTopUpSheet({
    required this.planId,
    required this.planName,
    super.key,
  });

  final String planId;
  final String planName;

  @override
  ConsumerState<SavingsPlanTopUpSheet> createState() =>
      _SavingsPlanTopUpSheetState();
}

class _SavingsPlanTopUpSheetState extends ConsumerState<SavingsPlanTopUpSheet> {
  final _controller = TextEditingController();
  String? _error;
  String? _submitted;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (ref
        .read(savingsPlanActionProvider)
        .busyFor(SavingsPlanAction.fund, widget.planId)) {
      setState(() => _error = savingsPlanBusyMessage);
      return;
    }
    switch (parseNairaToKobo(_controller.text, maxKobo: _maxTopUpKobo)) {
      case InvalidMoney(:final message):
        setState(() => _error = message);
      case ValidMoney(:final minorUnits):
        final amount = koboToNaira(minorUnits);
        setState(() {
          _error = null;
          _submitted = amount;
        });
        ref
            .read(savingsPlanActionProvider.notifier)
            .fund(widget.planId, amount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = ref
        .watch(savingsPlanActionProvider)
        .viewFor(SavingsPlanAction.fund, widget.planId);
    final sending = action.phase == SavingsPlanActionPhase.sending;

    void close() => Navigator.of(context).pop();

    return PopScope(canPop: !sending, child: _body(action, sending, close));
  }

  Widget _body(
    SavingsPlanActionState action,
    bool sending,
    VoidCallback close,
  ) {
    final theme = Theme.of(context);
    final colors = context.bocColors;
    switch (action.phase) {
      case SavingsPlanActionPhase.done:
        final hidden = ref.watch(homeBalanceHiddenProvider);
        final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final balance = formatApiAmount(
          action.result?.principalAmount,
          currency: 'NGN',
        );
        return AppActionSheet(
          icon: IconsaxPlusLinear.tick_circle,
          title: 'Money added',
          subtitle: 'Added to ${widget.planName} from Boc Flex Savings',
          footer: PrimaryButton(label: 'Done', onPressed: close),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BocMoneyText(
                formatApiAmount(_submitted, currency: 'NGN') ?? '',
                hidden: hidden,
                semanticsLabel: 'Amount added',
              ),
              if (balance != null) ...[
                const SizedBox(height: BocSpace.sm),
                Flex(
                  direction: stacked ? Axis.vertical : Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: stacked
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text('New plan balance', style: theme.textTheme.bodyMedium),
                    Text(
                      hidden ? '₦ ••••••' : balance,
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      case SavingsPlanActionPhase.unknown:
        return SavingsPlanNotConfirmedSheet(
          message: action.message ?? '',
          onClose: close,
        );
      case SavingsPlanActionPhase.idle ||
          SavingsPlanActionPhase.sending ||
          SavingsPlanActionPhase.failed:
        final message = _error ?? action.message;
        return AppActionSheet(
          icon: IconsaxPlusLinear.add_circle,
          title: 'Add money to ${widget.planName}',
          subtitle: 'From Boc Flex Savings',
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                label: 'Add money',
                onPressed: sending ? null : _submit,
              ),
              const SizedBox(height: BocSpace.xs),
              BocTextButton(label: 'Cancel', onPressed: sending ? null : close),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Amount (₦)',
                controller: _controller,
                enabled: !sending,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [ThousandsAmountFormatter()],
                onChanged: (_) => setState(() => _error = null),
              ),
              if (message != null) ...[
                const SizedBox(height: BocSpace.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.errorText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

/// Shown when Core may or may not have applied a plan action.
class SavingsPlanNotConfirmedSheet extends StatelessWidget {
  const SavingsPlanNotConfirmedSheet({
    required this.message,
    required this.onClose,
    super.key,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => AppActionSheet(
    icon: IconsaxPlusLinear.info_circle,
    title: 'Not confirmed',
    subtitle: message,
    footer: PrimaryButton(label: 'Close', onPressed: onClose),
    child: const SizedBox.shrink(),
  );
}
