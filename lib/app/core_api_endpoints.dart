/// Paths on the Core Service, relative to `$CORE_BASE_URL/v1`.
///
/// Core and User Service endpoints never share a constant set or a transport:
/// these go only through `coreApiServiceProvider`.
abstract final class CoreApiEndpoints {
  static const bankAccounts = '/me/bank-accounts';
  static const bankProducts = '/bank-products';

  static const ownAccountTransfer = '/me/intrabank/transfers/own';
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
}
