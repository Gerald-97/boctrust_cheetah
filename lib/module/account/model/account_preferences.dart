import 'package:equatable/equatable.dart';

enum TextSizePreference {
  small(0.9, 'Small'),
  medium(1.0, 'Medium'),
  large(1.15, 'Large');

  const TextSizePreference(this.multiplier, this.label);

  /// Applied once as `clamp(systemScale × multiplier, 0.9, 2.0)`.
  final double multiplier;
  final String label;
}

class AccessibilityPreferences extends Equatable {
  const AccessibilityPreferences({
    this.textSize = TextSizePreference.medium,
    this.boldText = false,
    this.highContrast = false,
  });

  factory AccessibilityPreferences.fromJson(Map<String, Object?> json) =>
      AccessibilityPreferences(
        textSize: TextSizePreference.values.firstWhere(
          (size) => size.name == json['textSize'],
          orElse: () => TextSizePreference.medium,
        ),
        boldText: json['boldText'] == true,
        highContrast: json['highContrast'] == true,
      );

  final TextSizePreference textSize;
  final bool boldText;
  final bool highContrast;

  Map<String, Object?> toJson() => {
    'textSize': textSize.name,
    'boldText': boldText,
    'highContrast': highContrast,
  };

  AccessibilityPreferences copyWith({
    TextSizePreference? textSize,
    bool? boldText,
    bool? highContrast,
  }) => AccessibilityPreferences(
    textSize: textSize ?? this.textSize,
    boldText: boldText ?? this.boldText,
    highContrast: highContrast ?? this.highContrast,
  );

  @override
  List<Object?> get props => [textSize, boldText, highContrast];
}

/// Stored on this device only until an API syncs them. Security alerts are
/// always on and have no toggle.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.transactions = true,
    this.savingsReminders = true,
    this.marketing = false,
  });

  factory NotificationPreferences.fromJson(Map<String, Object?> json) =>
      NotificationPreferences(
        transactions: json['transactions'] != false,
        savingsReminders: json['savingsReminders'] != false,
        marketing: json['marketing'] == true,
      );

  final bool transactions;
  final bool savingsReminders;
  final bool marketing;

  Map<String, Object?> toJson() => {
    'transactions': transactions,
    'savingsReminders': savingsReminders,
    'marketing': marketing,
  };

  NotificationPreferences copyWith({
    bool? transactions,
    bool? savingsReminders,
    bool? marketing,
  }) => NotificationPreferences(
    transactions: transactions ?? this.transactions,
    savingsReminders: savingsReminders ?? this.savingsReminders,
    marketing: marketing ?? this.marketing,
  );

  @override
  List<Object?> get props => [transactions, savingsReminders, marketing];
}
