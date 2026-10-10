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

  /// Live summary of one of the caller's accounts.
  static String bankAccountSummary(String accountNumber) =>
      '${bankAccount(accountNumber)}/summary';
  static const bankAccountSummaryTemplate =
      '$bankAccounts/{accountNumber}/summary';

  /// Live transaction history of one of the caller's accounts.
  static String bankAccountTransactions(String accountNumber) =>
      '${bankAccount(accountNumber)}/transactions';
  static const bankAccountTransactionsTemplate =
      '$bankAccounts/{accountNumber}/transactions';

  static const ownAccountTransfer = '/me/intrabank/transfers/own';

  /// Product account → BocFlex.
  static const intrabankWithdrawals = '/me/intrabank/withdrawals';

  /// BocFlex → another BOCTRUST customer's account.
  static const intrabankTransfers = '/me/intrabank/transfers';

  static const interbankBanks = '/me/interbank/banks';
  static const interbankNameEnquiry = '/me/interbank/name-enquiry';
  static const interbankTransfers = '/me/interbank/transfers';

  /// Full Core enquiry used only to resolve a BOCTRUST recipient name.
  static String accountEnquiry(String accountNumber) =>
      '/accounts/${Uri.encodeComponent(accountNumber)}/enquiry';
  static const accountEnquiryTemplate = '/accounts/{accountNumber}/enquiry';

  /// Status of an interbank transfer; [reference] is one path segment.
  static String interbankTransferStatus(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/status';
  static const interbankTransferStatusTemplate =
      '$interbankTransfers/{reference}/status';

  /// Live BankOne status of an interbank transfer, by its
  /// `transactionReference`. A read despite the POST method.
  static String interbankTransferRequery(String transactionReference) =>
      '$interbankTransfers/${Uri.encodeComponent(transactionReference)}'
      '/requery';
  static const interbankTransferRequeryTemplate =
      '$interbankTransfers/{reference}/requery';

  /// Live BankOne status of an intrabank transfer or withdrawal, by its
  /// `retrievalReference`. A read despite the POST method.
  static String intrabankTransferRequery(String retrievalReference) =>
      '$intrabankTransfers/${Uri.encodeComponent(retrievalReference)}'
      '/requery';
  static const intrabankTransferRequeryTemplate =
      '$intrabankTransfers/{retrievalReference}/requery';

  static const billers = '/me/bills/billers';
  static const billerCategories = '/me/bills/billers/categories';
  static const paymentItems = '/me/bills/payment-items';
  static const billPayments = '/me/bills/payments';

  /// The caller's transfer and bill-payment limits.
  static const transactionLimits = '/me/transaction-limits';

  /// The caller's savings plans, grouped by product.
  static const savingsPlans = '/me/savings-plans';

  /// One of the caller's savings plans; [planId] is one path segment.
  static String savingsPlan(String planId) =>
      '$savingsPlans/${Uri.encodeComponent(planId)}';
  static const savingsPlanTemplate = '$savingsPlans/{planId}';

  static const beneficiaries = '/me/beneficiaries';

  /// One saved beneficiary; [id] is one path segment.
  static String beneficiary(String id) =>
      '$beneficiaries/${Uri.encodeComponent(id)}';
  static const beneficiaryTemplate = '$beneficiaries/{beneficiaryId}';

  /// Every Core POST that moves money. Re-query POSTs are reads and are
  /// deliberately absent.
  static const moneyMoving = {
    ownAccountTransfer,
    intrabankWithdrawals,
    intrabankTransfers,
    interbankTransfers,
    billPayments,
  };
}
