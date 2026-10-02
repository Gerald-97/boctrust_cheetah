import 'package:equatable/equatable.dart';

/// An amount the customer typed, checked without floating point.
sealed class MoneyInput extends Equatable {
  const MoneyInput();
}

/// [minorUnits] is what Core expects: integer Kobo for transfers and
/// withdrawals, or a two-decimal Naira string for bill payments.
final class ValidMoney extends MoneyInput {
  const ValidMoney(this.minorUnits);
  final String minorUnits;

  @override
  List<Object?> get props => [minorUnits];
}

final class InvalidMoney extends MoneyInput {
  const InvalidMoney(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

final _amount = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// The amount in Kobo, or null when [text] is not a plain positive Naira
/// amount with at most two decimals. Accepts a leading ₦, spaces and
/// thousands separators.
BigInt? _kobo(String text) {
  final cleaned = text.replaceAll(RegExp(r'[₦,\s]'), '');
  final match = _amount.firstMatch(cleaned);
  if (match == null) return null;
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final kobo =
      BigInt.parse(match.group(1)!) * BigInt.from(100) + BigInt.parse(fraction);
  return kobo > BigInt.zero ? kobo : null;
}

const _invalidAmount = InvalidMoney('Enter a valid amount.');
const _overLimit = InvalidMoney('This amount exceeds your limit.');

/// Naira text → integer Kobo string, for transfers and withdrawals.
/// [maxKobo] is the inclusive upper bound, also in Kobo.
MoneyInput parseNairaToKobo(String text, {required String maxKobo}) {
  final kobo = _kobo(text);
  if (kobo == null) return _invalidAmount;
  if (kobo > BigInt.parse(maxKobo)) return _overLimit;
  return ValidMoney(kobo.toString());
}

/// Naira text → two-decimal Naira string, for bill payments.
/// [maxNaira] is the inclusive upper bound in whole Naira.
MoneyInput parseNairaAmount(String text, {required String maxNaira}) {
  final kobo = _kobo(text);
  if (kobo == null) return _invalidAmount;
  if (kobo > BigInt.parse(maxNaira) * BigInt.from(100)) return _overLimit;
  final digits = kobo.toString().padLeft(3, '0');
  final split = digits.length - 2;
  return ValidMoney('${digits.substring(0, split)}.${digits.substring(split)}');
}
