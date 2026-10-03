import 'package:equatable/equatable.dart';

import '../../home/model/user_home_model.dart';
import 'customer_bank_account_models.dart';

/// The Flex balance to show, from whichever service holds it.
class FlexBalance extends Equatable {
  const FlexBalance({
    required this.availableBalance,
    required this.ledgerBalance,
    this.productName,
    this.accountNumber,
  });

  /// Exact decimal Naira strings, or null when not published.
  final String? availableBalance;
  final String? ledgerBalance;
  final String? productName;

  /// The Core account number; null for the User Service wallet, which only
  /// a full reload refreshes.
  final String? accountNumber;

  bool get isCoreAccount => accountNumber != null;

  @override
  List<Object?> get props => [
    availableBalance,
    ledgerBalance,
    productName,
    accountNumber,
  ];
}

/// The customer's Flex balance.
///
/// Core is authoritative when the customer has an active Core Flex account.
/// Until Core has opened one, the User Service Flex wallet is shown instead,
/// so a customer always sees their balance. Neither inactive source is
/// shown.
FlexBalance? resolveFlexBalance({
  required CustomerBankAccountsData? core,
  required FlexWalletData? wallet,
}) {
  final account = core?.activeFlexAccount;
  if (account != null) {
    return FlexBalance(
      availableBalance: account.availableBalance,
      ledgerBalance: account.ledgerBalance,
      productName: account.productName,
      accountNumber: account.accountNumber,
    );
  }
  if (wallet != null && wallet.isActive) {
    return FlexBalance(
      availableBalance: wallet.availableBalance,
      ledgerBalance: wallet.ledgerBalance,
    );
  }
  return null;
}
