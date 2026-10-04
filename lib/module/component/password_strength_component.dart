import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../utils/auth_input.dart';

enum PasswordStrengthLevel { neutral, weak, fair, strong }

class PasswordStrength {
  const PasswordStrength({
    required this.value,
    required this.criteriaMet,
    required this.level,
  });

  factory PasswordStrength.evaluate(String value) {
    final criteriaMet = passwordCriteriaMet(value);
    final level = value.isEmpty
        ? PasswordStrengthLevel.neutral
        : criteriaMet <= 2
        ? PasswordStrengthLevel.weak
        : criteriaMet == 3
        ? PasswordStrengthLevel.fair
        : PasswordStrengthLevel.strong;
    return PasswordStrength(
      value: value,
      criteriaMet: criteriaMet,
      level: level,
    );
  }

  final String value;
  final int criteriaMet;
  final PasswordStrengthLevel level;

  bool get hasMinLength => hasPasswordMinLength(value);
  bool get hasLetter => hasPasswordLetter(value);
  bool get hasNumber => hasPasswordDigit(value);
  bool get hasSymbol => hasPasswordSymbol(value);

  String get label => switch (level) {
    PasswordStrengthLevel.neutral => 'Password strength',
    PasswordStrengthLevel.weak => 'Weak',
    PasswordStrengthLevel.fair => 'Fair',
    PasswordStrengthLevel.strong => 'Strong',
  };
}

class PasswordStrengthWidget extends StatelessWidget {
  const PasswordStrengthWidget({super.key, this.password = ''});

  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final strength = PasswordStrength.evaluate(password);
    final activeColor = switch (strength.level) {
      PasswordStrengthLevel.neutral => colorScheme.onSurfaceVariant,
      PasswordStrengthLevel.weak => colorScheme.error,
      PasswordStrengthLevel.fair => Colors.orange.shade700,
      PasswordStrengthLevel.strong => Colors.green.shade700,
    };
    final inactiveColor = colorScheme.outlineVariant;
    final criteria = [
      ('8+ characters', strength.hasMinLength),
      ('Letter', strength.hasLetter),
      ('Number', strength.hasNumber),
      ('Symbol', strength.hasSymbol),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (int i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(
                    left: i == 0 ? 0 : 3,
                    right: i == 3 ? 0 : 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: i < strength.criteriaMet
                        ? activeColor
                        : inactiveColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              strength.level == PasswordStrengthLevel.strong
                  ? IconsaxPlusBold.tick_circle
                  : IconsaxPlusLinear.info_circle,
              size: 16,
              color: activeColor,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                strength.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: activeColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final criterion in criteria)
              _PasswordCriterionChip(
                label: criterion.$1,
                met: criterion.$2,
                activeColor: activeColor,
              ),
          ],
        ),
      ],
    );
  }
}

class _PasswordCriterionChip extends StatelessWidget {
  const _PasswordCriterionChip({
    required this.label,
    required this.met,
    required this.activeColor,
  });

  final String label;
  final bool met;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = met ? activeColor : colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? IconsaxPlusBold.tick_circle : IconsaxPlusLinear.tick_circle,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
