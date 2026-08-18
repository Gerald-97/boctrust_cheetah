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
  tier1,
  tier2,
  nextOfKin,
  tier3,
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
  account,
}

enum AppSection { home, save, send, payments, account }

AppScreen appScreenForRoute(String? routeName) {
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
    case '/savings/new':
      return AppScreen.saveHub;
    case '/savings/flex':
    case '/savings/flex/top-up':
    case '/savings/flex/withdraw':
    case '/savings/flex/statement':
    case '/savings/flex/settings':
      return AppScreen.flex;
    case '/savings/target':
    case '/savings/target/create':
    case '/savings/target/sort':
      return AppScreen.target;
    case '/savings/lock':
    case '/savings/lock/create':
    case '/savings/lock/details':
    case '/savings/lock/add-money':
      return AppScreen.lock;
    case '/savings/group':
    case '/savings/group/create':
    case '/savings/group/contribute':
    case '/savings/group/invite':
    case '/savings/group/members':
      return AppScreen.group;
    case '/wallet/add-money':
    case '/wallet/bank-transfer':
    case '/wallet/card':
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
    case '/account/beneficiaries':
    case '/account/linked-banks':
    case '/account/security':
    case '/account/support':
    case '/account/support/chat':
    case '/account/support/call':
    case '/account/support/email':
    case '/account/legal/privacy':
    case '/account/legal/terms':
    case '/account/social/facebook':
    case '/account/social/x':
    case '/account/social/linkedin':
    case '/account/theme':
      return AppScreen.account;
    case '/account/tier':
      return AppScreen.tiers;
    case '/account/tier/bvn':
      return AppScreen.tier1;
    case '/account/tier/nin':
      return AppScreen.tier2;
    case '/account/tier/next-of-kin':
      return AppScreen.nextOfKin;
    case '/account/tier/address':
      return AppScreen.tier3;
    case '/account/loans':
    case '/account/loans/notify-me':
      return AppScreen.loans;
    case '/account/cards':
    case '/account/cards/notify-me':
      return AppScreen.cards;
    case '/notifications':
      return AppScreen.notifications;
    case '/transactions':
      return AppScreen.notifications;
    case '/transaction/authorize':
      return AppScreen.authPin;
    case '/transaction/receipt':
    case '/transaction/receipt/demo':
      return AppScreen.success;
    case '/payment/webview':
      return AppScreen.payments;
    default:
      return AppScreen.home;
  }
}
