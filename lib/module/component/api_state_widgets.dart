part of '../app_flow/app_ui.dart';

/// Semantic tone of an [ApiStateCard].
///
/// [blocked] means the backend contract for the feature is not published yet.
/// It is distinct from [error]: there is nothing for the user to retry.
enum ApiStateTone { info, success, warning, error, blocked }

/// Shared card for the non-data states of an API-driven section:
/// empty, error, informational, and contract-blocked.
///
/// Renders at most one action. Colour is never the only signal — every tone
/// pairs its colour with an icon and explicit text.
class ApiStateCard extends StatelessWidget {
  const ApiStateCard({
    required this.title,
    required this.message,
    required this.tone,
    this.actionLabel,
    this.onAction,
    super.key,
  }) : assert(
         (actionLabel == null) == (onAction == null),
         'Provide both actionLabel and onAction, or neither.',
       );

  final String title;
  final String message;
  final ApiStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color(context);
    final label = actionLabel;
    final action = onAction;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RoundedIcon(icon: _icon, color: color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.bocColors.textMain,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (label != null && action != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(label),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _color(BuildContext context) => switch (tone) {
    ApiStateTone.info => BocColors.blue,
    ApiStateTone.success => BocColors.green,
    ApiStateTone.warning => BocColors.gold,
    ApiStateTone.error => BocColors.red,
    ApiStateTone.blocked => BocColors.grey,
  };

  IconData get _icon => switch (tone) {
    ApiStateTone.info => IconsaxPlusLinear.info_circle,
    ApiStateTone.success => IconsaxPlusLinear.tick_circle,
    ApiStateTone.warning => IconsaxPlusLinear.danger,
    ApiStateTone.error => IconsaxPlusLinear.warning_2,
    ApiStateTone.blocked => IconsaxPlusLinear.lock,
  };
}

/// Section-level loading state with a descriptive semantics label.
///
/// Never expose a bare indeterminate spinner — screen readers need to know
/// what is loading.
class ApiLoadingSection extends StatelessWidget {
  const ApiLoadingSection({
    required this.label,
    this.compact = false,
    super.key,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 28),
        child: Column(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.bocColors.textMain,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
