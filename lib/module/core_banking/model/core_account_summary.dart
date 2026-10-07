import 'package:equatable/equatable.dart';

import 'core_json.dart';
import 'customer_bank_account_models.dart';

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
      availableBalance: coreAmount(json['availableBalance']),
      ledgerBalance: coreAmount(json['ledgerBalance']),
    );
  }

  final String accountNumber;
  final CoreAccountStatus status;
  final String? name;
  final String? product;
  final String? branch;

  /// Exact decimal strings in Naira, or null when not returned.
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
