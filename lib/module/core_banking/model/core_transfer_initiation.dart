import 'package:equatable/equatable.dart';

/// A check finalize may require. Only [pin] and [otp] are supported; an
/// initiation asking for [liveness] is never finalized.
enum CoreTransferCheck {
  pin('pin'),
  otp('otp'),
  liveness('liveness');

  const CoreTransferCheck(this.wireValue);
  final String wireValue;

  static CoreTransferCheck? parse(Object? value) {
    for (final check in values) {
      if (check.wireValue == value) return check;
    }
    return null;
  }
}

/// A pending transfer Core recorded on initiate. It is not a payment: no
/// money moves until finalize. Its [reference] is not a BankOne tracking
/// reference and is never used for a status check.
class CoreTransferInitiation extends Equatable {
  const CoreTransferInitiation({
    required this.reference,
    required this.checks,
    required this.expiresAt,
  });

  static final _reference = RegExp(r'^[a-f0-9]{12}$');

  /// Rejects a reply whose reference, checks or expiry Core does not
  /// document: an unknown or duplicate check, or checks without `pin`.
  factory CoreTransferInitiation.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid initiation.');
    final reference = json['reference'];
    if (reference is! String || !_reference.hasMatch(reference)) {
      throw const FormatException('Invalid initiation reference.');
    }
    final raw = json['requiredChecks'];
    if (raw is! List) throw const FormatException('Missing checks.');
    final checks = <CoreTransferCheck>{};
    for (final value in raw) {
      final check = CoreTransferCheck.parse(value);
      if (check == null || !checks.add(check)) {
        throw const FormatException('Invalid checks.');
      }
    }
    if (!checks.contains(CoreTransferCheck.pin)) {
      throw const FormatException('Checks without a PIN.');
    }
    final expiry = json['expiresAt'];
    final expiresAt = expiry is String ? DateTime.tryParse(expiry) : null;
    if (expiresAt == null) throw const FormatException('Invalid expiry.');
    return CoreTransferInitiation(
      reference: reference,
      checks: Set.unmodifiable(checks),
      expiresAt: expiresAt.toUtc(),
    );
  }

  final String reference;
  final Set<CoreTransferCheck> checks;
  final DateTime expiresAt;

  bool get needsOtp => checks.contains(CoreTransferCheck.otp);

  /// Whether this app can satisfy every check; liveness is not supported.
  bool get supported => !checks.contains(CoreTransferCheck.liveness);

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  @override
  List<Object?> get props => [reference, checks, expiresAt];
}
