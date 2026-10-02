import 'package:equatable/equatable.dart';

/// Core product code of the customer's main Flex account.
///
/// Shared with the User Service catalogue (`SavingsProductData.canOpenFlex`).
/// The Core contract publishes no example, so an account with any other code
/// is never treated as Flex: a wrong constant shows the balance as
/// unavailable rather than showing another account's balance.
const kFlexProductCode = 'bocFlex';

final _decimal = RegExp(r'^-?\d+(\.\d+)?$');

/// A money value kept as the exact decimal string the server sent, or null
/// when it is missing or not a plain decimal string. Never parsed to double.
String? _decimalString(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return _decimal.hasMatch(text) ? text : null;
}

String? _text(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

enum CoreAccountStatus {
  active('active'),
  frozen('frozen'),
  closed('closed'),

  /// A status this build does not know. Never treated as usable.
  unknown('unknown');

  const CoreAccountStatus(this.wireValue);
  final String wireValue;

  static CoreAccountStatus parse(Object? value) {
    for (final status in values) {
      if (status != unknown && status.wireValue == value) return status;
    }
    return unknown;
  }
}

/// One of the customer's Core bank accounts.
class CustomerBankAccount extends Equatable {
  const CustomerBankAccount({
    required this.productCode,
    required this.productName,
    required this.accountNumber,
    required this.status,
    this.openedAt,
    this.availableBalance,
    this.ledgerBalance,
  });

  final String productCode;
  final String productName;
  final String accountNumber;
  final CoreAccountStatus status;
  final DateTime? openedAt;

  /// Exact decimal strings in Naira, or null when not published.
  final String? availableBalance;
  final String? ledgerBalance;

  bool get isActive => status == CoreAccountStatus.active;

  /// The account a row describes, or null for a row missing its identity.
  static CustomerBankAccount? tryParse(Object? json) {
    if (json is! Map) return null;
    final productCode = _text(json['productCode']);
    final productName = _text(json['productName']);
    final accountNumber = _text(json['accountNumber']);
    if (productCode == null || productName == null || accountNumber == null) {
      return null;
    }
    final openedAt = json['openedAt'];
    return CustomerBankAccount(
      productCode: productCode,
      productName: productName,
      accountNumber: accountNumber,
      status: CoreAccountStatus.parse(json['status']),
      openedAt: openedAt is String
          ? DateTime.tryParse(openedAt)?.toUtc()
          : null,
      availableBalance: _decimalString(json['availableBalance']),
      ledgerBalance: _decimalString(json['ledgerBalance']),
    );
  }

  @override
  List<Object?> get props => [
    productCode,
    productName,
    accountNumber,
    status,
    openedAt,
    availableBalance,
    ledgerBalance,
  ];
}

/// An active catalogue product the customer has no account for yet.
class MissingBankProduct extends Equatable {
  const MissingBankProduct({
    required this.productCode,
    required this.productName,
  });

  final String productCode;
  final String productName;

  static MissingBankProduct? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = _text(json['productCode']);
    final name = _text(json['productName']);
    if (code == null || name == null) return null;
    return MissingBankProduct(productCode: code, productName: name);
  }

  @override
  List<Object?> get props => [productCode, productName];
}

/// `GET /me/bank-accounts`.
///
/// The numeric `totalAvailableBalance` is deliberately ignored: money is only
/// ever displayed from exact decimal strings.
class CustomerBankAccountsData extends Equatable {
  const CustomerBankAccountsData({
    required this.accounts,
    this.missingProducts = const [],
  });

  factory CustomerBankAccountsData.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Missing bank accounts.');
    final rows = json['products'];
    if (rows is! List) throw const FormatException('Missing products.');
    final parsed = rows
        .map(CustomerBankAccount.tryParse)
        .whereType<CustomerBankAccount>()
        .toList();
    // An account number claimed by two rows is ambiguous; neither is trusted.
    final counts = <String, int>{};
    for (final account in parsed) {
      counts.update(account.accountNumber, (n) => n + 1, ifAbsent: () => 1);
    }
    final missing = json['missingProducts'];
    return CustomerBankAccountsData(
      accounts: List.unmodifiable(
        parsed.where((account) => counts[account.accountNumber] == 1),
      ),
      missingProducts: List.unmodifiable(
        (missing is List ? missing : const [])
            .map(MissingBankProduct.tryParse)
            .whereType<MissingBankProduct>(),
      ),
    );
  }

  final List<CustomerBankAccount> accounts;
  final List<MissingBankProduct> missingProducts;

  /// The single active Flex account, or null when it is absent, not active,
  /// or ambiguous.
  CustomerBankAccount? get activeFlexAccount {
    final flex = accounts
        .where((account) => account.productCode == kFlexProductCode)
        .toList(growable: false);
    if (flex.length != 1 || !flex.single.isActive) return null;
    return flex.single;
  }

  @override
  List<Object?> get props => [accounts, missingProducts];
}
