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

  /// Prefix of the staged intrabank routes. The bare path is no longer a
  /// documented submit route.
  static const intrabankTransfers = '/me/intrabank/transfers';

  /// BocFlex → another BOCTRUST customer: records a pending transfer.
  static const intrabankTransferInitiate = '$intrabankTransfers/initiate';
  // The retired OTP request; removed once the service migrates.
  static String intrabankTransferOtp(String reference) =>
      '$intrabankTransfers/${Uri.encodeComponent(reference)}/otp/request';
  static const intrabankTransferOtpTemplate =
      '$intrabankTransfers/{reference}/otp/request';

  /// Verifies the PIN and has Core send the OTP when one is required.
  static String intrabankTransferPinVerify(String reference) =>
      '$intrabankTransfers/${Uri.encodeComponent(reference)}/pin/verify';
  static const intrabankTransferPinVerifyTemplate =
      '$intrabankTransfers/{reference}/pin/verify';
  static String intrabankTransferOtpResend(String reference) =>
      '$intrabankTransfers/${Uri.encodeComponent(reference)}/otp/resend';
  static const intrabankTransferOtpResendTemplate =
      '$intrabankTransfers/{reference}/otp/resend';
  static String intrabankTransferOtpVerify(String reference) =>
      '$intrabankTransfers/${Uri.encodeComponent(reference)}/otp/verify';
  static const intrabankTransferOtpVerifyTemplate =
      '$intrabankTransfers/{reference}/otp/verify';

  /// Moves the money of a pending intrabank transfer.
  static String intrabankTransferFinalize(String reference) =>
      '$intrabankTransfers/${Uri.encodeComponent(reference)}/finalize';
  static const intrabankTransferFinalizeTemplate =
      '$intrabankTransfers/{reference}/finalize';

  static const interbankBanks = '/me/interbank/banks';
  static const interbankNameEnquiry = '/me/interbank/name-enquiry';

  /// Prefix of the staged interbank routes. The bare path is no longer a
  /// documented submit route.
  static const interbankTransfers = '/me/interbank/transfers';

  /// BocFlex → another bank: records a pending transfer.
  static const interbankTransferInitiate = '$interbankTransfers/initiate';
  // The retired OTP request; removed once the service migrates.
  static String interbankTransferOtp(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/otp/request';
  static const interbankTransferOtpTemplate =
      '$interbankTransfers/{reference}/otp/request';

  /// Verifies the PIN and has Core send the OTP when one is required.
  static String interbankTransferPinVerify(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/pin/verify';
  static const interbankTransferPinVerifyTemplate =
      '$interbankTransfers/{reference}/pin/verify';
  static String interbankTransferOtpResend(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/otp/resend';
  static const interbankTransferOtpResendTemplate =
      '$interbankTransfers/{reference}/otp/resend';
  static String interbankTransferOtpVerify(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/otp/verify';
  static const interbankTransferOtpVerifyTemplate =
      '$interbankTransfers/{reference}/otp/verify';

  /// Moves the money of a pending interbank transfer.
  static String interbankTransferFinalize(String reference) =>
      '$interbankTransfers/${Uri.encodeComponent(reference)}/finalize';
  static const interbankTransferFinalizeTemplate =
      '$interbankTransfers/{reference}/finalize';

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

  /// Starts a limit change; PIN and OTP verify, then a bodyless finalize.
  static const transactionLimitsInitiate = '$transactionLimits/initiate';
  static String transactionLimitPinVerify(String reference) =>
      '$transactionLimits/${Uri.encodeComponent(reference)}/pin/verify';
  static const transactionLimitPinVerifyTemplate =
      '$transactionLimits/{reference}/pin/verify';
  static String transactionLimitOtpResend(String reference) =>
      '$transactionLimits/${Uri.encodeComponent(reference)}/otp/resend';
  static const transactionLimitOtpResendTemplate =
      '$transactionLimits/{reference}/otp/resend';
  static String transactionLimitOtpVerify(String reference) =>
      '$transactionLimits/${Uri.encodeComponent(reference)}/otp/verify';
  static const transactionLimitOtpVerifyTemplate =
      '$transactionLimits/{reference}/otp/verify';
  static String transactionLimitFinalize(String reference) =>
      '$transactionLimits/${Uri.encodeComponent(reference)}/finalize';
  static const transactionLimitFinalizeTemplate =
      '$transactionLimits/{reference}/finalize';

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
    billPayments,
    intrabankTransferFinalizeTemplate,
    interbankTransferFinalizeTemplate,
  };
}
