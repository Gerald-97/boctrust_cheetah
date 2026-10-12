import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../utils/utils.dart';
import '../../app_flow/app_ui.dart';
import '../provider/savings_plan_action_provider.dart';
import 'savings_plan_top_up_sheet.dart';

/// Withdraws [planId] early the moment it opens, then shows what Core paid.
/// Pops `true` only when Core confirmed the withdrawal.
class SavingsPlanWithdrawSheet extends ConsumerStatefulWidget {
  const SavingsPlanWithdrawSheet({required this.planId, super.key});

  final String planId;

  @override
  ConsumerState<SavingsPlanWithdrawSheet> createState() =>
      _SavingsPlanWithdrawSheetState();
}

class _SavingsPlanWithdrawSheetState
    extends ConsumerState<SavingsPlanWithdrawSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(savingsPlanActionProvider.notifier).liquidate(widget.planId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(savingsPlanActionProvider);
    final done = action.phase == SavingsPlanActionPhase.done;
    void close() => Navigator.of(context).pop(done);

    switch (action.phase) {
      case SavingsPlanActionPhase.done:
        final result = action.result;
        String? money(String? value) => formatApiAmount(value, currency: 'NGN');
        final rows = <(String, String?)>[
          ('Paid to Boc Flex', money(result?.amountPaidOut)),
          ('Interest earned', money(result?.interestAccrued)),
          ('Early withdrawal fee', money(result?.earlyWithdrawalFee)),
          if (result?.interestPending != '0.00')
            ('Interest still to come', money(result?.interestPending)),
        ];
        return AppActionSheet(
          icon: IconsaxPlusLinear.tick_circle,
          title: 'Withdrawn',
          subtitle: 'Your money is in Boc Flex Savings.',
          footer: PrimaryButton(label: 'Done', onPressed: close),
          child: BocSummaryGrid(
            items: [
              for (final (label, value) in rows)
                if (value != null) (label: label, value: value),
            ],
          ),
        );
      case SavingsPlanActionPhase.unknown:
        return SavingsPlanNotConfirmedSheet(
          message: action.message ?? '',
          onClose: close,
        );
      case SavingsPlanActionPhase.failed:
        return AppActionSheet(
          icon: IconsaxPlusLinear.info_circle,
          title: 'Not withdrawn',
          subtitle: action.message ?? '',
          footer: PrimaryButton(label: 'Close', onPressed: close),
          child: const SizedBox.shrink(),
        );
      case SavingsPlanActionPhase.idle || SavingsPlanActionPhase.sending:
        return const AppActionSheet(
          icon: IconsaxPlusLinear.money_send,
          title: 'Withdrawing',
          subtitle: 'Please wait.',
          child: Center(child: CircularProgressIndicator()),
        );
    }
  }
}
