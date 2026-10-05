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

  /// BocFlex → another BOCTRUST customer's account.
  static const intrabankTransfers = '/me/intrabank/transfers';

  static const interbankBanks = '/me/interbank/banks';
  static const interbankNameEnquiry = '/me/interbank/name-enquiry';
  static const interbankTransfers = '/me/interbank/transfers';

  /// Status of an interbank transfer; [reference] is one path segment.
  static String interbankTransferStatus(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/status';
  static const interbankTransferStatusTemplate =
      '$interbankTransfers/{reference}/status';

  static const billers = '/me/bills/billers';
  static const billerCategories = '/me/bills/billers/categories';
  static const paymentItems = '/me/bills/payment-items';
  static const billPayments = '/me/bills/payments';

  static const beneficiaries = '/me/beneficiaries';

  /// One saved beneficiary; [id] is one path segment.
  static String beneficiary(String id) =>
      '$beneficiaries/${Uri.encodeComponent(id)}';
  static const beneficiaryTemplate = '$beneficiaries/{beneficiaryId}';

  /// Every Core POST that moves money.
  static const moneyMoving = {
    ownAccountTransfer,
    intrabankWithdrawals,
    intrabankTransfers,
    interbankTransfers,
    billPayments,
  };
}
