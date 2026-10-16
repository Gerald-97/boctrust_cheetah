part of '../app_flow/app_ui.dart';

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
enum _PillTone { neutral, success, failed, unavailable }

/// A short status tag. Tones resolve from the theme so every tag stays
/// legible in light, dark and high-contrast modes.
class SmallPill extends StatelessWidget {
  const SmallPill({
    required this.text,
    this.foreground,
    this.background,
    super.key,
  }) : _tone = _PillTone.neutral;

  const SmallPill._tone(this.text, this._tone)
    : foreground = null,
      background = null;

  final String text;
  final Color? foreground;
  final Color? background;
  final _PillTone _tone;

  /// Verified, active, or otherwise complete.
  factory SmallPill.success(String text) =>
      SmallPill._tone(text, _PillTone.success);

  /// Pending, in progress, or awaiting review.
  factory SmallPill.pending(String text) => SmallPill(text: text);

  /// Failed or rejected.
  factory SmallPill.failed(String text) =>
      SmallPill._tone(text, _PillTone.failed);

  /// Unavailable, locked, or blocked by a missing backend contract.
  factory SmallPill.unavailable(String text) =>
      SmallPill._tone(text, _PillTone.unavailable);

  @override
  Widget build(BuildContext context) {
    final colors = context.bocColors;
    final (fg, bg) = switch (_tone) {
      _PillTone.success => (colors.successText, colors.successContainer),
      _PillTone.failed => (colors.errorText, colors.errorContainer),
      _PillTone.unavailable => (colors.textTertiary, colors.surfaceMuted),
      _PillTone.neutral => (
        foreground ?? colors.goldStrong,
        background ?? colors.goldPale,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: BocSpace.xs, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(BocRadius.pill),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}

/// Avatar backed by a profile HTTPS URL or a signed private-image URL.
///
/// Falls back to initials while loading, when no image exists, and on any load
/// failure. An image problem is always local to the avatar — it never surfaces
/// as a page-level error.
class ProfileAvatar extends ConsumerStatefulWidget {
  const ProfileAvatar({
    required this.displayName,
    this.imageUrl,
    this.radius = 28,
    super.key,
  });

  final String displayName;

  /// The profile's image URL or private image reference.
  final String? imageUrl;
  final double radius;

  @override
  ConsumerState<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<ProfileAvatar> {
  /// Guards against a refresh loop: at most one replacement URL is requested
  /// per widget lifetime after a forbidden image load.
  bool _retriedAfterForbidden = false;
  String? _failedDirectUrl;

  @override
  void didUpdateWidget(covariant ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _failedDirectUrl = null;
      _retriedAfterForbidden = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedState = ref.watch(profileImageSignedUrlProvider);
    final signed = signedState.data;
    final reference = widget.imageUrl?.trim();
    final parsed = reference == null ? null : Uri.tryParse(reference);
    final profileUrl = parsed?.scheme == 'https' && parsed!.hasAuthority
        ? reference
        : null;
    final directUrl = profileUrl == _failedDirectUrl ? null : profileUrl;
    final hasImage = reference != null && reference.isNotEmpty;

    if (hasImage && directUrl == null) {
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
      // Without a name there are no honest initials to show.
      child: initials.isEmpty
          ? Icon(IconsaxPlusBold.profile, size: widget.radius)
          : Text(
              initials,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: widget.radius * 0.55,
              ),
            ),
    );

    final displayUrl =
        directUrl ??
        (hasImage && signed != null && !signed.isExpired
            ? signed.imageUrl
            : null);
    if (displayUrl == null) {
      return Semantics(label: 'Profile photo', child: fallback);
    }

    return Semantics(
      label: 'Profile photo',
      child: ClipOval(
        child: Image.network(
          displayUrl,
          width: widget.radius * 2,
          height: widget.radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : fallback,
          errorBuilder: (context, error, stackTrace) {
            if (directUrl != null) {
              // The profile may hold a private URL that needs a fresh
              // signature. Try the signed endpoint after a direct load fails.
              Future<void>.microtask(() {
                if (!mounted || widget.imageUrl?.trim() != directUrl) return;
                setState(() => _failedDirectUrl = directUrl);
                unawaited(
                  ref
                      .read(profileImageSignedUrlProvider.notifier)
                      .ensureLoaded(),
                );
              });
            } else if (error is NetworkImageLoadException &&
                error.statusCode == 403 &&
                !_retriedAfterForbidden) {
              // A lapsed signed URL is recoverable exactly once.
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
    return result;
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
      (mode: AppThemeMode.light, icon: IconsaxPlusLinear.sun_1, label: 'Light'),
      (mode: AppThemeMode.dark, icon: IconsaxPlusLinear.moon, label: 'Dark'),
      (
        mode: AppThemeMode.system,
        icon: IconsaxPlusLinear.monitor_mobbile,
        label: 'System',
      ),
    ];
    return Row(
      children: options.map((option) {
        final selected = value == option.mode;
        return Expanded(
          child: InkWell(
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
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
