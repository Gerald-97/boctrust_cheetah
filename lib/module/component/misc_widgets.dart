part of '../app_flow/app_flow_navigator.dart';

class RoundedIcon extends StatelessWidget {
  const RoundedIcon({
    required this.icon,
    required this.color,
    this.size = 42,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.46),
    );
  }
}

/// Compact status chip.
///
/// Defaults to the brand gold so existing callers are unchanged. Pass
/// [foreground]/[background] for semantic states. The chip always carries its
/// own text, so colour is never the only status signal.
class SmallPill extends StatelessWidget {
  const SmallPill({
    required this.text,
    this.foreground,
    this.background,
    super.key,
  });

  final String text;
  final Color? foreground;
  final Color? background;

  /// Verified, active, or otherwise complete.
  factory SmallPill.success(String text) => SmallPill(
    text: text,
    foreground: BocColors.green,
    background: BocColors.greenPale,
  );

  /// Pending, in progress, or awaiting review.
  factory SmallPill.pending(String text) => SmallPill(text: text);

  /// Failed or rejected.
  factory SmallPill.failed(String text) => SmallPill(
    text: text,
    foreground: BocColors.red,
    background: BocColors.red.withValues(alpha: 0.12),
  );

  /// Unavailable, locked, or blocked by a missing backend contract.
  factory SmallPill.unavailable(String text) => SmallPill(
    text: text,
    foreground: BocColors.grey,
    background: BocColors.greyPale,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? context.bocColors.goldPale,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: foreground ?? BocColors.gold,
        ),
      ),
    );
  }
}

/// Avatar backed by a short-lived signed URL for a private profile image.
///
/// Falls back to initials while loading, when no image exists, and on any load
/// failure. An image problem is always local to the avatar — it never surfaces
/// as a page-level error.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({
    required this.displayName,
    required this.hasImage,
    this.radius = 28,
    super.key,
  });

  final String displayName;

  /// Whether the profile reports an image; the signed URL is only requested
  /// when there is something to fetch.
  final bool hasImage;
  final double radius;

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  /// Guards against a refresh loop: at most one replacement URL is requested
  /// per widget lifetime after a forbidden image load.
  bool _retriedAfterForbidden = false;

  @override
  Widget build(BuildContext context) {
    final signedState = ref.watch(profileImageSignedUrlProvider);
    final signed = signedState.data;

    if (widget.hasImage) {
      // Scheduled rather than called during build: ensureLoaded mutates
      // provider state.
      Future<void>.microtask(
        ref.read(profileImageSignedUrlProvider.notifier).ensureLoaded,
      );
    }

    final initials = _initialsOf(widget.displayName);
    final fallback = CircleAvatar(
      radius: widget.radius,
      backgroundColor: BocColors.navy,
      foregroundColor: BocColors.goldLight,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: widget.radius * 0.55,
        ),
      ),
    );

    if (!widget.hasImage || signed == null || signed.isExpired) {
      return Semantics(label: 'Profile photo', child: fallback);
    }

    return Semantics(
      label: 'Profile photo',
      child: ClipOval(
        child: Image.network(
          signed.imageUrl,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (context, error, stackTrace) {
            // A lapsed signed URL is recoverable exactly once; anything else
            // stays on initials.
            if (error is NetworkImageLoadException &&
                error.statusCode == 403 &&
                !_retriedAfterForbidden) {
              _retriedAfterForbidden = true;
              Future<void>.microtask(
                ref
                    .read(profileImageSignedUrlProvider.notifier)
                    .refreshAfterForbidden,
              );
            }
            return fallback;
          },
        ),
      ),
    );
  }

  static String _initialsOf(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2);
    final result = words.map((word) => word[0].toUpperCase()).join();
    return result.isEmpty ? 'BC' : result;
  }
}

class ThemeSelector extends StatelessWidget {
  const ThemeSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AppThemeMode value;
  final ValueChanged<AppThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = <({AppThemeMode mode, IconData icon, String label})>[
      (
        mode: AppThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: 'Light',
      ),
      (mode: AppThemeMode.dark, icon: Icons.dark_mode_outlined, label: 'Dark'),
      (
        mode: AppThemeMode.system,
        icon: Icons.settings_brightness_outlined,
        label: 'System',
      ),
    ];
    return Row(
      children: options.map((option) {
        final selected = value == option.mode;
        return Expanded(
          child: InkWell(
            onTap: () => onChanged(option.mode),
            borderRadius: BorderRadius.circular(13),
            child: Container(
              margin: EdgeInsets.only(
                right: option.mode == AppThemeMode.system ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? BocColors.navy : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? BocColors.navy
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    option.icon,
                    size: 20,
                    color: selected
                        ? BocColors.goldLight
                        : Theme.of(context).iconTheme.color,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: selected ? BocColors.goldLight : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
