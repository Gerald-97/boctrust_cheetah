part of '../app_flow/app_flow_navigator.dart';

class LabeledField extends StatelessWidget {
  const LabeledField({
    required this.label,
    required this.value,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ],
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    this.initialValue,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final String? initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: initialValue,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          decoration: InputDecoration(hintText: hintText, isDense: true),
        ),
      ],
    );
  }
}

class SelectableMethodTile extends StatelessWidget {
  const SelectableMethodTile({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? context.bocColors.bluePale
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? BocColors.navy : Theme.of(context).dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            RoundedIcon(icon: icon, color: BocColors.gold),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? BocColors.navy
                      : Theme.of(context).dividerColor,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Center(
                      child: CircleAvatar(
                        radius: 5,
                        backgroundColor: BocColors.navy,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class OtpBox extends StatelessWidget {
  const OtpBox({required this.value, super.key});
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 52,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value == '•' ? Theme.of(context).dividerColor : BocColors.navy,
          width: 1.5,
        ),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
      ),
    );
  }
}

class PasswordStrengthCard extends StatelessWidget {
  const PasswordStrengthCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bocColors.greenPale,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: BocColors.green),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'At least 8 characters, 1 number, 1 symbol',
              style: TextStyle(fontSize: 11.5),
            ),
          ),
          Text(
            'Strong password',
            style: TextStyle(
              color: BocColors.green,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({required this.filled, super.key});
  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        4,
        (index) => Container(
          width: 15,
          height: 15,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: index < filled
                ? BocColors.navy
                : Theme.of(context).dividerColor,
          ),
        ),
      ),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({required this.hint, super.key});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        isDense: true,
      ),
    );
  }
}

class DemoToggle extends StatefulWidget {
  const DemoToggle({required this.initialValue, super.key});

  final bool initialValue;

  @override
  State<DemoToggle> createState() => _DemoToggleState();
}

class _DemoToggleState extends State<DemoToggle> {
  late bool value = widget.initialValue;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: (nextValue) => setState(() => value = nextValue),
    );
  }
}
