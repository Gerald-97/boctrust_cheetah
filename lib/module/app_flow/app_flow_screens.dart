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
  securityCenter,
  deleteAccount,
  accountStatement,
  preferences,
  myProfile,
  notificationPreferences,
  accessibilityPreferences,
  savingsPlanDetail,
  transactionDetail,
  smartSaveCreate,
  fixedDepositCreate,
  padiCreate,
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
  loans,
  cards,
  unavailable,
  account,
}

enum AppSection { home, save, send, payments, account }

/// What a registered route opens and whether it needs a session.
class AppRouteDefinition {
  /// A screen still hosted by [AppFlowNavigator].
  const AppRouteDefinition(AppScreen this.screen, {this.isPublic = false})
    : unavailable = null,
      page = null;

  /// A route with no working feature yet, rendered by
  /// [UnavailableFeatureScreen].
  const AppRouteDefinition.unavailable(
    UnavailableDestination this.unavailable, {
    this.isPublic = false,
  }) : screen = AppScreen.unavailable,
       page = null;

  /// A standalone screen that navigates with named routes, outside the flow.
  const AppRouteDefinition.page(
    Widget Function() this.page, {
    this.isPublic = false,
  }) : screen = null,
       unavailable = null;

  final AppScreen? screen;
  final Widget Function()? page;

  /// Reachable without a signed-in session. Every other route needs a session
  /// and a created PIN.
  final bool isPublic;
  final UnavailableDestination? unavailable;
}

/// The single route registry. [AppRoutes.allRoutes], [AppRoutes.publicRoutes]
/// and [appScreenForRoute] are all derived from it.
///
/// Public routes: entry, sign-in and recovery, first-PIN setup (which needs a
/// session but no PIN yet), and static support and legal pages that hold no
/// customer data.
const appRouteDefinitions = <String, AppRouteDefinition>{
  // Entry, sign-in and recovery.
  AppRoutes.bootstrap: AppRouteDefinition(AppScreen.bootstrap, isPublic: true),
  AppRoutes.onboarding: AppRouteDefinition(
    AppScreen.onboarding,
    isPublic: true,
  ),
  AppRoutes.verificationMethod: AppRouteDefinition(
    AppScreen.verifyMethod,
    isPublic: true,
  ),
  AppRoutes.otp: AppRouteDefinition(AppScreen.otp, isPublic: true),
  AppRoutes.createPassword: AppRouteDefinition(
    AppScreen.createPassword,
    isPublic: true,
  ),
  AppRoutes.login: AppRouteDefinition(AppScreen.login, isPublic: true),
  AppRoutes.biometricLogin: AppRouteDefinition(AppScreen.login, isPublic: true),
  AppRoutes.passwordReset: AppRouteDefinition(
    AppScreen.passwordReset,
    isPublic: true,
  ),
  AppRoutes.newDeviceOtp: AppRouteDefinition(
    AppScreen.newDeviceOtp,
    isPublic: true,
  ),
  AppRoutes.createFirstPin: AppRouteDefinition(
    AppScreen.createFirstPin,
    isPublic: true,
  ),

  AppRoutes.home: AppRouteDefinition(AppScreen.home),

  // Savings.
  AppRoutes.savingsHub: AppRouteDefinition(AppScreen.saveHub),
  AppRoutes.flexSave: AppRouteDefinition(AppScreen.flex),
  AppRoutes.flexTopUp: AppRouteDefinition(AppScreen.addMoney),
  AppRoutes.flexWithdraw: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Withdrawals',
      heading: 'Unavailable',
      message: 'Withdrawals are not available yet.',
      section: AppSection.save,
      capability: FeatureCapability.flexWithdraw,
    ),
  ),
  AppRoutes.flexStatement: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Savings statements',
      heading: 'Unavailable',
      message: 'Savings statements are not available yet.',
      section: AppSection.save,
      capability: FeatureCapability.flexStatement,
    ),
  ),
  AppRoutes.flexSettings: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Auto-save',
      heading: 'Unavailable',
      message: 'Auto-save is not available yet.',
      section: AppSection.save,
      capability: FeatureCapability.flexAutoSave,
    ),
  ),
  AppRoutes.newSavingsChooser: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.targetSave: AppRouteDefinition(AppScreen.target),
  AppRoutes.targetSaveCreate: AppRouteDefinition(AppScreen.smartSaveCreate),
  AppRoutes.targetSort: AppRouteDefinition.unavailable(savingsPlansUnavailable),
  AppRoutes.lockSave: AppRouteDefinition(AppScreen.lock),
  AppRoutes.lockCreate: AppRouteDefinition(AppScreen.fixedDepositCreate),
  AppRoutes.lockDetails: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.lockAddMoney: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupSave: AppRouteDefinition(AppScreen.group),
  AppRoutes.groupCreate: AppRouteDefinition(AppScreen.padiCreate),
  AppRoutes.groupContribute: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupInvite: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupMembers: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.savingsPlanDetail: AppRouteDefinition(AppScreen.savingsPlanDetail),

  // Funding.
  AppRoutes.addMoney: AppRouteDefinition(AppScreen.addMoney),
  AppRoutes.bankTransferFunding: AppRouteDefinition(AppScreen.addMoney),
  AppRoutes.cardFunding: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Card funding',
      heading: 'Unavailable',
      message: 'Card funding is not available yet.',
      section: AppSection.save,
      capability: FeatureCapability.cardFunding,
    ),
  ),

  // Send.
  AppRoutes.sendHub: AppRouteDefinition(AppScreen.sendHub),
  AppRoutes.sendOwnAccount: AppRouteDefinition(AppScreen.sendOwn),
  AppRoutes.sendBeneficiary: AppRouteDefinition(AppScreen.sendBeneficiary),
  AppRoutes.sendOtherBank: AppRouteDefinition(AppScreen.sendBank),

  // Payments.
  AppRoutes.paymentsHub: AppRouteDefinition(AppScreen.payments),
  AppRoutes.airtime: AppRouteDefinition(AppScreen.airtime),
  AppRoutes.data: AppRouteDefinition(AppScreen.data),
  AppRoutes.billerListElectricity: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billerListWater: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billerListCable: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billerListInternet: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billerListEducation: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billerListMore: AppRouteDefinition(AppScreen.billerList),
  AppRoutes.billPay: AppRouteDefinition(AppScreen.billPay),
  AppRoutes.scanToPay: AppRouteDefinition(AppScreen.scan),
  AppRoutes.paymentWebView: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Payment',
      heading: 'Payment checkout is unavailable',
      message: 'Card and hosted checkout payments are not available yet.',
      section: AppSection.payments,
      capability: FeatureCapability.cardFunding,
    ),
  ),

  // Account and verification.
  AppRoutes.account: AppRouteDefinition(AppScreen.account),
  AppRoutes.tierOverview: AppRouteDefinition(AppScreen.tiers),
  // Compatibility routes: both open the identity screen, preselecting the
  // identity type rather than standing for a whole tier.
  AppRoutes.tier1Bvn: AppRouteDefinition(AppScreen.kycIdentity),
  AppRoutes.tier2Nin: AppRouteDefinition(AppScreen.kycIdentity),
  AppRoutes.governmentIdVerification: AppRouteDefinition(
    AppScreen.kycGovernmentId,
  ),
  AppRoutes.nextOfKin: AppRouteDefinition(AppScreen.nextOfKin),
  AppRoutes.tier3Address: AppRouteDefinition(AppScreen.kycUtilityBill),
  AppRoutes.kycCacDocument: AppRouteDefinition(AppScreen.kycCacDocument),
  AppRoutes.kycBankStatement: AppRouteDefinition(AppScreen.kycBankStatement),
  AppRoutes.manageBeneficiaries: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Beneficiaries',
      heading: 'Beneficiaries are unavailable',
      message: 'Saved beneficiaries are not available yet.',
      section: AppSection.account,
      capability: FeatureCapability.beneficiaries,
    ),
  ),
  AppRoutes.linkedBanks: AppRouteDefinition(AppScreen.linkedBanks),
  AppRoutes.securitySettings: AppRouteDefinition(AppScreen.securityCenter),
  AppRoutes.deleteAccount: AppRouteDefinition(AppScreen.deleteAccount),
  AppRoutes.accountStatement: AppRouteDefinition(AppScreen.accountStatement),
  AppRoutes.myProfile: AppRouteDefinition(AppScreen.myProfile),
  AppRoutes.preferences: AppRouteDefinition(AppScreen.preferences),
  AppRoutes.notificationPreferences: AppRouteDefinition(
    AppScreen.notificationPreferences,
  ),
  AppRoutes.accessibilityPreferences: AppRouteDefinition(
    AppScreen.accessibilityPreferences,
  ),
  // Preferences holds the theme picker.
  AppRoutes.themeSettings: AppRouteDefinition(AppScreen.preferences),
  AppRoutes.loansComingSoon: AppRouteDefinition(AppScreen.loans),
  AppRoutes.loansNotifyMe: AppRouteDefinition(AppScreen.loans),
  AppRoutes.cardsComingSoon: AppRouteDefinition(AppScreen.cards),
  AppRoutes.cardsNotifyMe: AppRouteDefinition(AppScreen.cards),

  // Support, legal and social: public, and never customer data.
  AppRoutes.support: AppRouteDefinition.unavailable(
    supportUnavailable,
    isPublic: true,
  ),
  AppRoutes.supportChat: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Chat with support',
      heading: 'In-app chat is unavailable',
      message: supportContactMessage,
      section: AppSection.account,
    ),
    isPublic: true,
  ),
  AppRoutes.supportCall: AppRouteDefinition.unavailable(
    supportUnavailable,
    isPublic: true,
  ),
  AppRoutes.supportEmail: AppRouteDefinition.unavailable(
    supportUnavailable,
    isPublic: true,
  ),
  // No policy-content endpoint and no bundled copy exist.
  AppRoutes.privacyPolicy: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Privacy Policy',
      heading: 'The privacy policy is unavailable',
      message: 'The privacy policy is not available in the app yet.',
      section: AppSection.account,
    ),
    isPublic: true,
  ),
  AppRoutes.terms: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Terms & Conditions',
      heading: 'The terms and conditions are unavailable',
      message: 'The terms and conditions are not available in the app yet.',
      section: AppSection.account,
    ),
    isPublic: true,
  ),
  // Official handles have not been supplied.
  AppRoutes.socialFacebook: AppRouteDefinition.unavailable(
    socialUnavailable,
    isPublic: true,
  ),
  AppRoutes.socialX: AppRouteDefinition.unavailable(
    socialUnavailable,
    isPublic: true,
  ),
  AppRoutes.socialLinkedIn: AppRouteDefinition.unavailable(
    socialUnavailable,
    isPublic: true,
  ),

  // Activity and transactions.
  AppRoutes.notifications: AppRouteDefinition.page(NotificationsScreen.new),
  // The live history screen replaces this page once the capability is on.
  AppRoutes.transactionHistory: AppRouteDefinition.unavailable(
    UnavailableDestination(
      title: 'Transactions',
      heading: 'Transaction history is unavailable',
      message: 'Your transaction history cannot be displayed yet.',
      section: AppSection.payments,
      capability: FeatureCapability.transactionHistory,
    ),
  ),
  AppRoutes.transactionDetail: AppRouteDefinition(AppScreen.transactionDetail),
  AppRoutes.transactionAuthorization: AppRouteDefinition(AppScreen.authPin),
  AppRoutes.receipt: AppRouteDefinition(AppScreen.success),
};

AppScreen appScreenForRoute(String? routeName) =>
    appRouteDefinitions[routeName]?.screen ?? AppScreen.home;

/// The hub route for a bottom-navigation section, for screens outside the
/// flow.
String appRouteForSection(AppSection section) => switch (section) {
  AppSection.home => AppRoutes.home,
  AppSection.save => AppRoutes.savingsHub,
  AppSection.send => AppRoutes.sendHub,
  AppSection.payments => AppRoutes.paymentsHub,
  AppSection.account => AppRoutes.account,
};
