import 'package:equatable/equatable.dart';

import 'core_json.dart';
import 'core_money.dart';
import 'customer_bank_account_models.dart';

/// A whole, non-negative Kobo number as a Naira decimal string, else null.
///
/// The docs only say "number"; live staging showed the summary's balances
/// are Kobo (the account list's "99,864.50" arrived as 9986450).
String? _koboToNaira(Object? value) =>
    value is num && value >= 0 && value == value.roundToDouble()
    ? koboToNaira('${value.toInt()}')
    : null;

/// A live BankOne summary of one of the customer's accounts. The internal
/// `customerId` in the reply is deliberately not kept.
class CoreAccountSummary extends Equatable {
  const CoreAccountSummary({
    required this.accountNumber,
    required this.status,
    this.name,
    this.product,
    this.branch,
    this.availableBalance,
    this.ledgerBalance,
  });

  factory CoreAccountSummary.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid account summary.');
    final accountNumber = coreText(json['accountNumber']);
    if (accountNumber == null) {
      throw const FormatException('Missing account number.');
    }
    return CoreAccountSummary(
      accountNumber: accountNumber,
      status: CoreAccountStatus.parse(
        coreText(json['accountStatus'])?.toLowerCase(),
      ),
      name: coreText(json['name']),
      product: coreText(json['product']),
      branch: coreText(json['branch']),
      availableBalance: _koboToNaira(json['availableBalance']),
      ledgerBalance: _koboToNaira(json['ledgerBalance']),
    );
  }

  final String accountNumber;
  final CoreAccountStatus status;
  final String? name;
  final String? product;
  final String? branch;

  /// Naira decimal strings converted from the reply's Kobo, or null.
  final String? availableBalance;
  final String? ledgerBalance;

  @override
  List<Object?> get props => [
    accountNumber,
    status,
    name,
    product,
    branch,
    availableBalance,
    ledgerBalance,
  ];
}
