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

class SmallPill extends StatelessWidget {
  const SmallPill({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.bocColors.goldPale,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: BocColors.gold,
        ),
      ),
    );
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
