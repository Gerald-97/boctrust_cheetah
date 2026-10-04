part of '../app_flow/app_flow_navigator.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BocSpace.gutter,
        BocSpace.xxs,
        BocSpace.xs,
        BocSpace.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (action != null) BocTextButton(label: action, onPressed: onAction),
        ],
      ),
    );
  }
}

/// One transaction in a list. The sign and tint follow [direction] from the
/// server, never the amount text, so a withdrawal can never read as money in.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.direction,
    this.pending = false,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Server-formatted, unsigned amount.
  final String amount;
  final TransactionDirection direction;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final (icon, tint, container, sign, amountColor) = switch (direction) {
      TransactionDirection.credit => (
        IconsaxPlusLinear.arrow_down_1,
        colors.success,
        colors.successContainer,
        '+',
        colors.successText,
      ),
      TransactionDirection.debit => (
        IconsaxPlusLinear.arrow_up,
        colors.error,
        colors.errorContainer,
        '−',
        colors.textPrimary,
      ),
      TransactionDirection.internal => (
        IconsaxPlusLinear.arrow_swap_horizontal,
        colors.smartSaveAccent,
        colors.smartSaveContainer,
        '',
        colors.textPrimary,
      ),
    };
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: BocSpace.md,
            vertical: BocSpace.sm,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: container,
                  borderRadius: BorderRadius.circular(BocRadius.sm),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(icon, color: tint, size: 20),
                ),
              ),
              const SizedBox(width: BocSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        text: subtitle,
                        children: [
                          if (pending)
                            TextSpan(
                              text: '  Pending',
                              style: TextStyle(color: colors.warningText),
                            ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BocSpace.xs),
              Text(
                '$sign$amount',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: amountColor)
                    .figures,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ContactCard extends StatelessWidget {
  const ContactCard({
    required this.initials,
    required this.name,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String initials;
  final String name;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: BocColors.navy,
            foregroundColor: BocColors.goldLight,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class BankRow extends StatelessWidget {
  const BankRow({
    required this.name,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.semanticsLabel,
    this.enabled = true,
    super.key,
  });

  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? semanticsLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onTap != null;
    return Semantics(
      button: interactive,
      enabled: interactive,
      label: semanticsLabel ?? '$name. $subtitle',
      onTap: interactive ? onTap : null,
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 48,
        enabled: interactive,
        onTap: interactive ? onTap : null,
        leading: DecoratedBox(
          decoration: BoxDecoration(
            color: context.bocColors.smartSaveContainer,
            borderRadius: BorderRadius.circular(BocRadius.sm),
          ),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(
              IconsaxPlusLinear.bank,
              color: interactive
                  ? context.bocColors.smartSaveAccent
                  : context.bocColors.textDisabled,
            ),
          ),
        ),
        title: Text(name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        trailing:
            trailing ??
            (interactive ? const Icon(IconsaxPlusLinear.arrow_right_3) : null),
      ),
    );
  }
}

class ReceiptRow extends StatelessWidget {
  const ReceiptRow({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// A grouped card of [SettingsTile]s with an optional caption above it.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    required this.children,
    this.caption,
    this.padding = const EdgeInsets.fromLTRB(
      BocSpace.gutter,
      0,
      BocSpace.gutter,
      BocSpace.md,
    ),
    super.key,
  });

  final List<Widget> children;
  final String? caption;

  /// Outer padding; pass [EdgeInsets.zero] inside an already padded list.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final caption = this.caption;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(
                left: BocSpace.xxs,
                bottom: BocSpace.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  caption,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(BocRadius.md),
              border: Theme.of(context).brightness == Brightness.dark
                  ? Border.all(color: colors.border)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(BocRadius.md),
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index != children.length - 1)
                      Divider(
                        height: 1,
                        indent: BocSpace.md + 24 + BocSpace.sm,
                        color: colors.border,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One settings row: icon, title, subtitle and a trailing chevron, switch or
/// tag. Rows are at least 56px tall and tappable across their full width.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    super.key,
  }) : _toggleValue = null,
       _onToggle = null;

  /// A row whose whole surface toggles [value]. A null [onChanged] disables
  /// the row, e.g. for a capability that is not available yet.
  const SettingsTile.toggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.trailing,
    this.titleColor,
    super.key,
  }) : onTap = null,
       _toggleValue = value,
       _onToggle = onChanged;

  final IconData icon;
  final String title;
  final String subtitle;

  /// Shown before the chevron or switch, e.g. a "Not available yet" tag.
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides the title colour, e.g. error text for "Delete account".
  final Color? titleColor;
  final bool? _toggleValue;
  final ValueChanged<bool>? _onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final theme = Theme.of(context);
    final toggleValue = _toggleValue;
    final onToggle = _onToggle;
    final isToggle = toggleValue != null;
    final enabled = isToggle ? onToggle != null : true;
    // At large text sizes a tag beside the chevron or switch would squeeze
    // the title, so it moves under the subtitle instead.
    final stackTrailing = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final Widget end = isToggle
        ? ExcludeSemantics(
            child: Switch(value: toggleValue, onChanged: onToggle),
          )
        : onTap == null
        ? const SizedBox.shrink()
        : Icon(IconsaxPlusLinear.arrow_right_3, color: colors.textTertiary);
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BocSpace.md,
          vertical: BocSpace.sm,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color:
                  titleColor ??
                  (theme.brightness == Brightness.dark
                      ? colors.textPrimary
                      : BocColors.navy),
            ),
            const SizedBox(width: BocSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color:
                          titleColor ?? (enabled ? null : colors.textDisabled),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                  if (trailing != null && stackTrailing) ...[
                    const SizedBox(height: BocSpace.xxs),
                    trailing!,
                  ],
                ],
              ),
            ),
            if (trailing != null && !stackTrailing) ...[
              const SizedBox(width: BocSpace.xs),
              trailing!,
            ],
            const SizedBox(width: BocSpace.xs),
            end,
          ],
        ),
      ),
    );
    if (isToggle) {
      return MergeSemantics(
        child: Semantics(
          toggled: toggleValue,
          enabled: enabled,
          child: InkWell(
            onTap: onToggle == null ? null : () => onToggle(!toggleValue),
            child: row,
          ),
        ),
      );
    }
    return InkWell(onTap: onTap, child: row);
  }
}
