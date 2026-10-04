part of '../app_flow/app_flow_navigator.dart';

class LimitRow extends StatelessWidget {
  const LimitRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFFD7DEE7), fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ).figures,
            ),
          ),
        ],
      ),
    );
  }
}

class TierCard extends StatelessWidget {
  const TierCard({
    required this.tier,
    required this.title,
    required this.subtitle,
    required this.requirements,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.isCurrentTier = false,
    this.actionLabel,
    this.lockReason,
    super.key,
  });

  final int tier;
  final String title;
  final String subtitle;
  final List<String> requirements;
  final String status;
  final Color statusColor;
  final bool isCurrentTier;

  /// Null for a locked card or an unknown backend status: the card renders as
  /// disabled rather than navigating somewhere it cannot act.
  final VoidCallback? onTap;
  final String? actionLabel;

  /// Backend-supplied explanation shown inside a locked card.
  final String? lockReason;

  @override
  Widget build(BuildContext context) {
    final reason = lockReason;
    final action = actionLabel;
    final enabled = onTap != null;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label:
          '$title. ${isCurrentTier ? 'Current tier. ' : ''}'
          '$status${reason == null ? '' : '. $reason'}',
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || isCurrentTier ? 1 : 0.62,
        child: _card(context, reason: reason, action: action, enabled: enabled),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String? reason,
    required String? action,
    required bool enabled,
  }) {
    return SurfaceCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BocTierBadge(tier: tier, size: 40),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(fontSize: 14),
                      ),
                    ),
                    if (isCurrentTier) ...[
                      const SizedBox(width: BocSpace.xs),
                      const SmallPill(text: 'Current tier'),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: requirements
                      .map(
                        (value) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Text(
                            value,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    if (action != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(color: context.bocColors.textMain),
                      ),
                      Text(
                        action,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                if (reason != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        IconsaxPlusLinear.lock,
                        size: 12,
                        color: BocColors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          reason,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontSize: 10.5,
                                color: context.bocColors.textMain,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (enabled) const Icon(IconsaxPlusLinear.arrow_right_3, size: 18),
        ],
      ),
    );
  }
}

class StepIndicator extends StatelessWidget {
  const StepIndicator({required this.activeStep, this.label, super.key});
  final int activeStep;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            2,
            (index) => Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == 0 ? 6 : 0),
                decoration: BoxDecoration(
                  color: index + 1 < activeStep
                      ? BocColors.gold
                      : index + 1 == activeStep
                      ? BocColors.navy
                      : Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              'STEP $activeStep OF 2',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            if (label != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: BocColors.gold,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Shows the status of one verification requirement.
///
/// The status is always supplied by the caller from backend state. This widget
/// never asserts that something is verified — an initiation response means the
/// job was submitted, not that it succeeded.
class VerificationCard extends StatelessWidget {
  const VerificationCard({
    required this.title,
    required this.description,
    required this.statusLabel,
    required this.statusColor,
    this.value,
    this.icon = IconsaxPlusLinear.personalcard,
    super.key,
  });

  final String title;
  final String description;
  final String statusLabel;
  final Color statusColor;

  /// Masked identifier, when one has been submitted.
  final String? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final displayValue = value;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Semantics(
              label: '$title $statusLabel',
              child: Row(
                children: [
                  RoundedIcon(icon: icon, color: statusColor, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      displayValue ?? description,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: displayValue == null
                            ? context.bocColors.textMain
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// File picker affordance for document upload.
///
/// The accepted types and size limit are supplied through [helperText] so they
/// track the API contract rather than being fixed in the component.
class DashedLikeUpload extends StatelessWidget {
  const DashedLikeUpload({
    required this.title,
    required this.helperText,
    required this.onTap,
    this.selectedFileName,
    this.enabled = true,
    this.loading = false,
    super.key,
  });

  final String title;
  final String helperText;
  final VoidCallback onTap;
  final String? selectedFileName;
  final bool enabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = selectedFileName;
    final interactive = enabled && !loading;
    final accent = interactive ? BocColors.blue : BocColors.grey;
    final subtitle = selected ?? helperText;

    return Semantics(
      button: true,
      enabled: interactive,
      label: selected == null
          ? '$title. $helperText'
          : '$title. Selected file $selected',
      onTap: interactive ? onTap : null,
      excludeSemantics: true,
      child: InkWell(
        onTap: interactive ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: accent, width: 1.4),
          ),
          child: Row(
            children: [
              if (loading)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              else
                RoundedIcon(
                  icon: selected == null
                      ? IconsaxPlusLinear.document_upload
                      : IconsaxPlusLinear.document_text,
                  color: accent,
                  size: 40,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: interactive ? null : BocColors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.bocColors.textMain,
                        fontSize: 11,
                        fontWeight: selected == null
                            ? FontWeight.w400
                            : FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
