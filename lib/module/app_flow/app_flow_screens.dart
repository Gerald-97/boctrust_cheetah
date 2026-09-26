part of 'app_flow_navigator.dart';

enum AppScreen {
  bootstrap,
  onboarding,
  verifyMethod,
  otp,
  createPassword,
  login,
  passwordReset,
  newDeviceOtp,
  createFirstPin,
  tiers,
  kycIdentity,
  kycGovernmentId,
  kycUtilityBill,
  kycCacDocument,
  kycBankStatement,
  nextOfKin,
  linkedBanks,
  home,
  saveHub,
  addMoney,
  sendHub,
  sendOwn,
  sendBeneficiary,
  sendBank,
  authPin,
  success,
  payments,
  scan,
  airtime,
  data,
  billerList,
  billPay,
  flex,
  target,
  lock,
  group,
  notifications,
  loans,
  cards,
  routePreview,
  account,
}

enum AppSection { home, save, send, payments, account }

enum AppPreviewRoute {
  savingsNew,
  flexTopUp,
  flexWithdraw,
  flexStatement,
  flexSettings,
  targetCreate,
  targetSort,
  lockCreate,
  lockDetails,
  lockAddMoney,
  groupCreate,
  groupContribute,
  groupInvite,
  groupMembers,
  bankTransferFunding,
  cardFunding,
  accountBeneficiaries,
  accountSecurity,
  accountSupport,
  supportChat,
  supportCall,
  supportEmail,
  privacyPolicy,
  terms,
  socialFacebook,
  socialX,
  socialLinkedIn,
  themeSettings,
  transactionHistory,
  paymentWebView,
}

AppPreviewRoute? appPreviewRouteForRoute(String? routeName) {
  switch (routeName) {
    case '/savings/new':
      return AppPreviewRoute.savingsNew;
    case '/savings/flex/top-up':
      return AppPreviewRoute.flexTopUp;
    case '/savings/flex/withdraw':
      return AppPreviewRoute.flexWithdraw;
    case '/savings/flex/statement':
      return AppPreviewRoute.flexStatement;
    case '/savings/flex/settings':
      return AppPreviewRoute.flexSettings;
    case '/savings/target/create':
      return AppPreviewRoute.targetCreate;
    case '/savings/target/sort':
      return AppPreviewRoute.targetSort;
    case '/savings/lock/create':
      return AppPreviewRoute.lockCreate;
    case '/savings/lock/details':
      return AppPreviewRoute.lockDetails;
    case '/savings/lock/add-money':
      return AppPreviewRoute.lockAddMoney;
    case '/savings/group/create':
      return AppPreviewRoute.groupCreate;
    case '/savings/group/contribute':
      return AppPreviewRoute.groupContribute;
    case '/savings/group/invite':
      return AppPreviewRoute.groupInvite;
    case '/savings/group/members':
      return AppPreviewRoute.groupMembers;
    case '/wallet/bank-transfer':
      return AppPreviewRoute.bankTransferFunding;
    case '/wallet/card':
      return AppPreviewRoute.cardFunding;
    case '/account/beneficiaries':
      return AppPreviewRoute.accountBeneficiaries;
    case '/account/security':
      return AppPreviewRoute.accountSecurity;
    case '/account/support':
      return AppPreviewRoute.accountSupport;
    case '/account/support/chat':
      return AppPreviewRoute.supportChat;
    case '/account/support/call':
      return AppPreviewRoute.supportCall;
    case '/account/support/email':
      return AppPreviewRoute.supportEmail;
    case '/account/legal/privacy':
      return AppPreviewRoute.privacyPolicy;
    case '/account/legal/terms':
      return AppPreviewRoute.terms;
    case '/account/social/facebook':
      return AppPreviewRoute.socialFacebook;
    case '/account/social/x':
      return AppPreviewRoute.socialX;
    case '/account/social/linkedin':
      return AppPreviewRoute.socialLinkedIn;
    case '/account/theme':
      return AppPreviewRoute.themeSettings;
    case '/transactions':
      return AppPreviewRoute.transactionHistory;
    case '/payment/webview':
      return AppPreviewRoute.paymentWebView;
    default:
      return null;
  }
}

AppScreen appScreenForRoute(String? routeName) {
  if (appPreviewRouteForRoute(routeName) != null) {
    return AppScreen.routePreview;
  }
  switch (routeName) {
    case '/bootstrap':
      return AppScreen.bootstrap;
    case '/onboarding':
      return AppScreen.onboarding;
    case '/onboarding/verification-method':
      return AppScreen.verifyMethod;
    case '/onboarding/otp':
      return AppScreen.otp;
    case '/onboarding/create-password':
      return AppScreen.createPassword;
    case '/login':
    case '/login/biometric':
      return AppScreen.login;
    case '/login/password-reset':
      return AppScreen.passwordReset;
    case '/login/new-device-otp':
      return AppScreen.newDeviceOtp;
    case '/onboarding/create-pin':
      return AppScreen.createFirstPin;
    case '/home':
      return AppScreen.home;
    case '/savings':
      return AppScreen.saveHub;
    case '/savings/flex':
      return AppScreen.flex;
    case '/savings/target':
      return AppScreen.target;
    case '/savings/lock':
      return AppScreen.lock;
    case '/savings/group':
      return AppScreen.group;
    case '/wallet/add-money':
      return AppScreen.addMoney;
    case '/send':
      return AppScreen.sendHub;
    case '/send/own-account':
      return AppScreen.sendOwn;
    case '/send/beneficiary':
      return AppScreen.sendBeneficiary;
    case '/send/other-bank':
      return AppScreen.sendBank;
    case '/payments':
      return AppScreen.payments;
    case '/payments/airtime':
      return AppScreen.airtime;
    case '/payments/data':
      return AppScreen.data;
    case '/payments/billers/electricity':
    case '/payments/billers/water':
    case '/payments/billers/cable':
    case '/payments/billers/internet':
    case '/payments/billers/education':
    case '/payments/billers/more':
      return AppScreen.billerList;
    case '/payments/bill-pay':
      return AppScreen.billPay;
    case '/payments/scan-to-pay':
      return AppScreen.scan;
    case '/account':
      return AppScreen.account;
    case '/account/tier':
      return AppScreen.tiers;
    // Compatibility routes: both open the identity screen, preselecting the
    // identity type rather than standing for a whole tier.
    case '/account/tier/bvn':
    case '/account/tier/nin':
      return AppScreen.kycIdentity;
    case '/account/tier/government-id':
      return AppScreen.kycGovernmentId;
    case '/account/tier/next-of-kin':
      return AppScreen.nextOfKin;
    case '/account/tier/address':
      return AppScreen.kycUtilityBill;
    case '/account/tier/cac':
      return AppScreen.kycCacDocument;
    case '/account/tier/bank-statement':
      return AppScreen.kycBankStatement;
    case '/account/linked-banks':
      return AppScreen.linkedBanks;
    case '/account/loans':
    case '/account/loans/notify-me':
      return AppScreen.loans;
    case '/account/cards':
    case '/account/cards/notify-me':
      return AppScreen.cards;
    case '/notifications':
      return AppScreen.notifications;
    case '/transaction/authorize':
      return AppScreen.authPin;
    case '/transaction/receipt':
      return AppScreen.success;
    default:
      return AppScreen.home;
  }
}
