abstract final class ApiEndpoints {
  static const signup = '/auth/signup';
  static const requestOtp = '/auth/otp/request';
  static const verifyAccount = '/auth/verify-account';
  static const createFirstPassword = '/auth/create-first-password';
  static const forgotPassword = '/auth/password/forgot';
  static const verifyPasswordOtp = '/auth/password/verify';
  static const resetPassword = '/auth/password/reset';
  static const changePassword = '/auth/password/change';
  static const forgotPin = '/auth/pin/forgot';
  static const verifyPinOtp = '/auth/pin/verify';
  static const resetPin = '/auth/pin/reset';
  static const createFirstPin = '/auth/pin/create-first';
  static const changePin = '/auth/pin/change';
  static const login = '/auth/login';
  static const verifyCurrentPassword = '/auth/password/verify-current';
  static const verifyCurrentPin = '/auth/pin/verify-current';
  static const verifyDevice = '/auth/device/verify';
  static const fcmToken = '/auth/fcm-token';
  static const logout = '/auth/logout';
  static const initiateIdentifierVerification =
      '/auth/identifier-verification/initiate';
  static const verifyIdentifier = '/auth/identifier-verification/verify';
  static const ownProfile = '/users/me/profile';
  static const ownTier = '/users/me/tier';
  static const ownHome = '/users/me/home';
  static const profileImageSignedUrl = '/users/me/profile-image/signed-url';

  static const banks = '/users/banks';
  static const withdrawalBankAccounts = '/users/me/withdrawal-bank-accounts';
  static const resolveWithdrawalBankAccount =
      '/users/me/withdrawal-bank-accounts/resolve';
  static String withdrawalBankAccount(String bankAccountId) =>
      '$withdrawalBankAccounts/${Uri.encodeComponent(bankAccountId)}';

  static const ownKycStatus = '/users/me/kyc/status';

  static const initiateIdentityVerification = '/users/me/kyc/identity/initiate';
  static const initiateGovernmentIdVerification =
      '/users/me/kyc/government-id/initiate';
  static const initiateUtilityBillUpload =
      '/users/me/kyc/utility-bill/initiate';
  static String completeUtilityBillUpload(String verificationId) =>
      '/users/me/kyc/utility-bill/'
      '${Uri.encodeComponent(verificationId)}/complete';

  static const publicOperations = <({String method, String path})>{
    (method: 'POST', path: signup),
    (method: 'POST', path: requestOtp),
    (method: 'POST', path: verifyAccount),
    (method: 'POST', path: createFirstPassword),
    (method: 'POST', path: forgotPassword),
    (method: 'POST', path: verifyPasswordOtp),
    (method: 'POST', path: resetPassword),
    (method: 'POST', path: forgotPin),
    (method: 'POST', path: verifyPinOtp),
    (method: 'POST', path: resetPin),
    (method: 'POST', path: login),
    (method: 'POST', path: verifyDevice),
  };

  static bool isPublic(String method, String path) => publicOperations.contains(
    (method: method.toUpperCase(), path: normalize(path)),
  );

  static String normalize(String path) {
    var normalized = Uri.parse(path).path;
    const prefix = '/api/v1';
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length);
    }
    if (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
