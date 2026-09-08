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
    this.controller,
    this.initialValue,
    this.hintText,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.autovalidateMode,
    this.autofillHints,
    this.inputFormatters,
    this.suffix,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputAction? textInputAction;
  final AutovalidateMode? autovalidateMode;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffix;

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
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          maxLines: obscureText ? 1 : maxLines,
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: autovalidateMode,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffix,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class AppPasswordField extends StatefulWidget {
  const AppPasswordField({
    required this.label,
    this.controller,
    this.initialValue,
    this.hintText,
    this.validator,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.autovalidateMode,
    this.autofillHints,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hintText;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputAction? textInputAction;
  final AutovalidateMode? autovalidateMode;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    final label = _hidden ? 'Show password' : 'Hide password';
    return AppTextField(
      label: widget.label,
      controller: widget.controller,
      initialValue: widget.initialValue,
      hintText: widget.hintText,
      validator: widget.validator,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      autovalidateMode: widget.autovalidateMode,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      obscureText: _hidden,
      suffix: IconButton(
        tooltip: label,
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        icon: Icon(
          _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
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

class OtpExpiryLabel extends StatefulWidget {
  const OtpExpiryLabel({required this.expiresAt, super.key});

  final DateTime? expiresAt;

  @override
  State<OtpExpiryLabel> createState() => _OtpExpiryLabelState();
}

class _OtpExpiryLabelState extends State<OtpExpiryLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant OtpExpiryLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expiresAt != widget.expiresAt) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.expiresAt == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining.inSeconds <= 0) _timer?.cancel();
    });
  }

  Duration get _remaining {
    final expiresAt = widget.expiresAt;
    if (expiresAt == null) return Duration.zero;
    final remaining = expiresAt.toUtc().difference(DateTime.now().toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.expiresAt == null) return const SizedBox.shrink();
    final remaining = _remaining;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Text(
      remaining == Duration.zero
          ? 'Code expired'
          : 'Code expires in $minutes:$seconds',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class TestOtpBanner extends ConsumerWidget {
  const TestOtpBanner({
    required this.flow,
    required this.controller,
    super.key,
  });

  final TestOtpFlow flow;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(stagingModeProvider)) return const SizedBox.shrink();
    final hint = ref.watch(testOtpProvider.select((codes) => codes[flow]));
    if (hint == null || hint.isExpired) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.tertiary),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TEST MODE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'OTP code: ${hint.code}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                OtpExpiryLabel(expiresAt: hint.expiresAt),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              controller.text = hint.code;
              controller.selection = TextSelection.collapsed(
                offset: controller.text.length,
              );
            },
            child: const Text('Use code'),
          ),
        ],
      ),
    );
  }
}

class PinSecurityWarningBox extends StatelessWidget {
  const PinSecurityWarningBox({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Choose a PIN that is hard to guess. Avoid repeated digits (1111), sequences (1234), and personal dates.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
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
