import 'package:equatable/equatable.dart';

import 'customer_bank_account_models.dart';

/// Who froze an account. Core reads never include this; only the freeze and
/// unfreeze replies do.
enum CoreFrozenBy {
  customer('customer'),
  admin('admin'),

  /// A value this build does not know.
  unknown('unknown');

  const CoreFrozenBy(this.wireValue);
  final String wireValue;

  static CoreFrozenBy? parse(Object? value) {
    if (value == null) return null;
    for (final by in values) {
      if (by != unknown && by.wireValue == value) return by;
    }
    return unknown;
  }
}

/// The account state Core returns from a freeze or an unfreeze.
class AccountFreezeResult extends Equatable {
  const AccountFreezeResult({
    required this.accountNumber,
    required this.status,
    this.frozenBy,
    this.frozenAt,
  });

  factory AccountFreezeResult.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid freeze reply.');
    final accountNumber = json['accountNumber'];
    if (accountNumber is! String || accountNumber.trim().isEmpty) {
      throw const FormatException('Invalid freeze reply.');
    }
    final frozenAt = json['frozenAt'];
    return AccountFreezeResult(
      accountNumber: accountNumber.trim(),
      status: CoreAccountStatus.parse(json['status']),
      frozenBy: CoreFrozenBy.parse(json['frozenBy']),
      frozenAt: frozenAt is String
          ? DateTime.tryParse(frozenAt)?.toUtc()
          : null,
    );
  }

  final String accountNumber;
  final CoreAccountStatus status;
  final CoreFrozenBy? frozenBy;
  final DateTime? frozenAt;

  @override
  List<Object?> get props => [accountNumber, status, frozenBy, frozenAt];
}

/// Core's reply to a request for an unfreeze code. Core's staging-only
/// `otpCode` field is deliberately not read, so it can never be kept.
class UnfreezeOtpReply extends Equatable {
  const UnfreezeOtpReply({required this.otpSent, this.otpExpiresAt});

  factory UnfreezeOtpReply.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid code reply.');
    final otpExpiresAt = json['otpExpiresAt'];
    return UnfreezeOtpReply(
      otpSent: json['otpSent'] == true,
      otpExpiresAt: otpExpiresAt is String
          ? DateTime.tryParse(otpExpiresAt)?.toUtc()
          : null,
    );
  }

  final bool otpSent;
  final DateTime? otpExpiresAt;

  @override
  List<Object?> get props => [otpSent, otpExpiresAt];
}

/// What happened to a freeze, an unfreeze code request or an unfreeze.
sealed class AccountFreezeOutcome<T> extends Equatable {
  const AccountFreezeOutcome();
}

/// Core accepted the request.
final class FreezeSucceeded<T> extends AccountFreezeOutcome<T> {
  const FreezeSucceeded(this.result);
  final T result;

  @override
  List<Object?> get props => [result];
}

/// `401`: Core rejected the credentials. On confirm-unfreeze it does not say
/// whether the PIN or the code was wrong.
final class FreezeWrongCredentials<T> extends AccountFreezeOutcome<T> {
  const FreezeWrongCredentials();

  @override
  List<Object?> get props => [];
}

/// `403`: the bank froze the account; only support can unfreeze it.
final class FreezeBankFrozen<T> extends AccountFreezeOutcome<T> {
  const FreezeBankFrozen();

  @override
  List<Object?> get props => [];
}

/// `404`, or an account number that was never sent: the account is not one
/// of the caller's.
final class FreezeNotFound<T> extends AccountFreezeOutcome<T> {
  const FreezeNotFound();

  @override
  List<Object?> get props => [];
}

/// `409`: the account is already in the requested state.
final class FreezeConflict<T> extends AccountFreezeOutcome<T> {
  const FreezeConflict();

  @override
  List<Object?> get props => [];
}

/// No reliable answer: a network failure, a timeout, or any status Core does
/// not document. The request is never resent automatically.
final class FreezeUncertain<T> extends AccountFreezeOutcome<T> {
  const FreezeUncertain();

  @override
  List<Object?> get props => [];
}
