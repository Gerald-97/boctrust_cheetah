import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import '../../../app/app_router.dart';
import '../../../app/feature_capability.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/account_freeze_models.dart';
import '../provider/account_freeze_provider.dart';
import 'account_freeze_flow.dart';

/// Shown for as long as Core reports the account frozen. A bank freeze can
/// only be lifted by support, so the action changes to match.
class FrozenAccountBanner extends ConsumerWidget {
  const FrozenAccountBanner._(this.accountNumber, this.message, {super.key});

  /// The customer's Boc Flex account.
  factory FrozenAccountBanner.flex(String accountNumber, {Key? key}) =>
      FrozenAccountBanner._(
        accountNumber,
        'Your Boc Flex account is frozen. Transfers and other outgoing '
        'payments are paused.',
        key: key,
      );

  /// A savings product account, whose freeze pauses plan withdrawals.
  factory FrozenAccountBanner.savings(
    String accountNumber,
    String productName, {
    Key? key,
  }) => FrozenAccountBanner._(
    accountNumber,
    'Your $productName account is frozen. Withdrawals are paused.',
    key: key,
  );

  final String accountNumber;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final bankFrozen =
        ref.watch(accountFreezeMemoryProvider)[accountNumber] ==
        CoreFrozenBy.admin;
    // Unfreezing is staging-only for now; elsewhere support handles it.
    final canUnfreeze =
        ref.watch(
          featureAvailabilityProvider(FeatureCapability.freezeAccount),
        ) ==
        FeatureAvailability.available;
    final useSupport = bankFrozen || !canUnfreeze;
    return Padding(
      padding: const EdgeInsets.only(top: BocSpace.xs),
      child: Container(
        padding: const EdgeInsets.all(BocSpace.sm),
        decoration: BoxDecoration(
          color: colors.infoContainer,
          borderRadius: BorderRadius.circular(BocRadius.md),
          border: Border.all(color: colors.info.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(IconsaxPlusLinear.lock, size: 20, color: colors.info),
                const SizedBox(width: BocSpace.xs),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: BocSpace.xs),
            SecondaryButton(
              label: useSupport ? 'Contact support' : 'Unfreeze account',
              onPressed: useSupport
                  ? () => Navigator.of(context).pushNamed(AppRoutes.support)
                  : () => openUnfreezeFlow(context, ref, accountNumber),
            ),
          ],
        ),
      ),
    );
  }
}
