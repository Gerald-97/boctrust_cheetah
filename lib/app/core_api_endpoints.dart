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

  /// BocFlex → another BOCTRUST account.
  static const intrabankTransfers = '/me/intrabank/transfers';
  static const interbankBanks = '/me/interbank/banks';
  static const interbankNameEnquiry = '/me/interbank/name-enquiry';
  static const interbankTransfers = '/me/interbank/transfers';

  /// The status of one interbank transfer; [reference] is one path segment.
  static String interbankTransferStatus(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/status';

  static const billers = '/me/bills/billers';
  static const billerCategories = '/me/bills/billers/categories';
  static const paymentItems = '/me/bills/payment-items';
  static const billPayments = '/me/bills/payments';

  static const beneficiaries = '/me/beneficiaries';

  /// One saved beneficiary; [beneficiaryId] is one path segment.
  static String beneficiary(String beneficiaryId) =>
      '$beneficiaries/${Uri.encodeComponent(beneficiaryId)}';

  /// OCR that reads a number from a photo: snap returns the longest run of
  /// 4+ digits, scan requires the whole text to be digits.
  static const snapToPay = '/me/snap-to-pay';
  static const scanToPay = '/me/scan-to-pay';
}
