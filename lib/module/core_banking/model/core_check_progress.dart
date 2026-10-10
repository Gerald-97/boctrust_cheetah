import 'package:equatable/equatable.dart';

import 'core_json.dart';
import 'core_transfer_initiation.dart';

/// Core's reply to a PIN verify, OTP verify or OTP resend: which checks are
/// required, completed and pending, and whether an OTP was sent.
///
/// The development/staging `otpCode` is deliberately dropped: the code always
/// comes from the customer.
class CoreCheckProgress extends Equatable {
  const CoreCheckProgress({
    this.reference,
    this.required = const {},
    this.completed = const {},
    this.pending = const {},
    this.otpSent,
    this.otpExpiresAt,
  });

  /// Refuses an unknown check name rather than guessing its meaning.
  factory CoreCheckProgress.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid check progress.');
    Set<CoreTransferCheck> checks(String key) {
      final raw = json[key];
      if (raw == null) return const {};
      if (raw is! List) throw FormatException('Invalid $key.');
      return Set.unmodifiable({
        for (final value in raw)
          CoreTransferCheck.parse(value) ??
              (throw FormatException('Unknown check in $key.')),
      });
    }

    final sent = json['otpSent'];
    return CoreCheckProgress(
      reference: coreText(json['reference']),
      required: checks('requiredChecks'),
      completed: checks('completedChecks'),
      pending: checks('pendingChecks'),
      otpSent: sent is bool ? sent : null,
      otpExpiresAt: DateTime.tryParse(
        coreText(json['otpExpiresAt']) ?? '',
      )?.toUtc(),
    );
  }

  final String? reference;
  final Set<CoreTransferCheck> required;
  final Set<CoreTransferCheck> completed;
  final Set<CoreTransferCheck> pending;
  final bool? otpSent;
  final DateTime? otpExpiresAt;

  @override
  List<Object?> get props => [
    reference,
    required,
    completed,
    pending,
    otpSent,
    otpExpiresAt,
  ];
}
