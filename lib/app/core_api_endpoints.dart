/// Paths on the Core Service, relative to `$CORE_BASE_URL/v1`.
///
/// Core and User Service endpoints never share a constant set or a transport:
/// these go only through `coreApiServiceProvider`.
abstract final class CoreApiEndpoints {
  static const bankAccounts = '/me/bank-accounts';
  static const bankProducts = '/bank-products';

  /// One of the caller's accounts; [accountNumber] is one path segment.
  static String bankAccount(String accountNumber) =>
      '$bankAccounts/${Uri.encodeComponent(accountNumber)}';

  static const ownAccountTransfer = '/me/intrabank/transfers/own';

  /// Product account → BocFlex.
  static const intrabankWithdrawals = '/me/intrabank/withdrawals';
}
