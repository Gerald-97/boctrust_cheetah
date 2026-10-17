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
    this.isFrozen = false,
  });

  /// Exact decimal Naira strings, or null when not published.
  final String? availableBalance;
  final String? ledgerBalance;
  final String? productName;

  /// The Core account number; null for the User Service wallet, which only
  /// a full reload refreshes.
  final String? accountNumber;

  /// True only for a frozen Core account.
  final bool isFrozen;

  bool get isCoreAccount => accountNumber != null;

  /// The Core account number while that account is frozen, otherwise null.
  String? get frozenAccountNumber => isFrozen ? accountNumber : null;

  @override
  List<Object?> get props => [
    availableBalance,
    ledgerBalance,
    productName,
    accountNumber,
    isFrozen,
  ];
}

/// The customer's Flex balance.
///
/// Core is authoritative whenever the customer has a Core Flex account, even
/// a frozen one, which keeps its Core balance. Until Core has opened one, the
/// active User Service Flex wallet is shown instead, so a customer always
/// sees their balance.
FlexBalance? resolveFlexBalance({
  required CustomerBankAccountsData? core,
  required FlexWalletData? wallet,
}) {
  final account = core?.flexAccount;
  if (account != null) {
    return FlexBalance(
      availableBalance: account.availableBalance,
      ledgerBalance: account.ledgerBalance,
      productName: account.productName,
      accountNumber: account.accountNumber,
      isFrozen: account.status == CoreAccountStatus.frozen,
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
