part of '../app_flow/app_ui.dart';

/// Bottom-sheet shell carrying Cheetah's card surface, gold rounded icon and
/// typography into modal overlays.
///
/// The app defines no `bottomSheetTheme`, so each branded sheet opts in here
/// rather than through a global theme that would restyle unrelated modals.
class AppActionSheet extends StatelessWidget {
  const AppActionSheet({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.iconColor,
    this.iconBackground,
    this.footer,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? footer;

  /// Opens [builder] as a branded modal sheet and returns its pop value.
  ///
  /// The sheet returns a value rather than invoking a callback captured from
  /// the caller's `State`, so a launcher can re-check `mounted` before acting
  /// on the result. [isDismissible] and [enableDrag] let a sheet refuse a
  /// barrier tap or a drag, e.g. while it is sending money.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: true,
    // The sheet draws its own handle inside its scroll view.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: builder,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('app-action-sheet'),
      color: theme.cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ResponsiveContent(
        maxWidth: 560,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (iconColor != null && iconBackground != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: iconBackground,
                        borderRadius: BorderRadius.circular(BocRadius.sm),
                      ),
                      child: SizedBox.square(
                        dimension: 40,
                        child: Icon(icon, size: 20, color: iconColor),
                      ),
                    )
                  else
                    RoundedIcon(icon: icon, color: BocColors.gold),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              child,
              if (footer != null) ...[
                const SizedBox(height: 20),
                Divider(height: 1, color: theme.dividerColor),
                const SizedBox(height: 16),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Branded choice row for [AppActionSheet], matching `SettingsTile` typography
/// so an overlay reads as part of the account surface it was opened from.
class AppActionSheetOption extends StatelessWidget {
  const AppActionSheetOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              RoundedIcon(icon: icon, color: BocColors.gold, size: 34),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(IconsaxPlusLinear.arrow_right_3, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// A confirmation sheet that resolves `true` only from its labelled confirm
/// action; the scrim, Back and the cancel action all resolve `false`. It
/// invokes nothing itself, so callers act only on an explicit confirmation.
abstract final class AppConfirmSheet {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        void close(bool value) => Navigator.of(sheetContext).pop(value);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            BocSpace.gutter,
            0,
            BocSpace.gutter,
            BocSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: BocSpace.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: BocSpace.lg),
              // The safe choice leads; a destructive confirm never looks
              // like the default.
              if (destructive) ...[
                PrimaryButton(
                  label: cancelLabel,
                  onPressed: () => close(false),
                ),
                const SizedBox(height: BocSpace.xs),
                DestructiveButton(
                  label: confirmLabel,
                  onPressed: () => close(true),
                ),
              ] else ...[
                PrimaryButton(
                  label: confirmLabel,
                  onPressed: () => close(true),
                ),
                const SizedBox(height: BocSpace.xs),
                SecondaryButton(
                  label: cancelLabel,
                  onPressed: () => close(false),
                ),
              ],
            ],
          ),
        );
      },
    );
    return confirmed ?? false;
  }
}
