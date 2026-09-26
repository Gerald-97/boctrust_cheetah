part of '../app_flow/app_flow_navigator.dart';

/// Full-width primary action: navy with a gold label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    super.key,
  });

  final String label;

  /// Null renders the button disabled, which is how a screen blocks a second
  /// submission while a mutation is in flight.
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shows a spinner in place of the label and blocks taps, keeping the width.
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget child = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: BocColors.goldLight,
            ),
          )
        : _ButtonLabel(label: label, icon: icon);
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: BocSpace.md,
            vertical: BocSpace.sm,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: Semantics(
          label: isLoading ? '$label, in progress' : null,
          child: child,
        ),
      ),
    );
  }
}

/// Full-width secondary action: light fill, hairline border, navy label.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 56),
          padding: const EdgeInsets.symmetric(
            horizontal: BocSpace.md,
            vertical: BocSpace.sm,
          ),
        ),
        child: _ButtonLabel(label: label, icon: icon),
      ),
    );
  }
}

/// Low-emphasis action such as "Go back and edit" or "See all".
class BocTextButton extends StatelessWidget {
  const BocTextButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

/// A destructive action. Its label must name the consequence ("Delete
/// account", "Withdraw and forfeit interest"), never "Yes"; it is styled
/// quieter than [PrimaryButton] so it is never the default-looking choice.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 56),
          backgroundColor: colors.errorContainer,
          foregroundColor: colors.errorText,
          disabledBackgroundColor: colors.errorContainer.withValues(alpha: 0.5),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.errorText,
                ),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) return Text(label, textAlign: TextAlign.center);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: BocSpace.xs),
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
  }
}
