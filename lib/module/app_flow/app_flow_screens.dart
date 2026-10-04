part of 'app_flow_navigator.dart';

enum AppScreen {
  securityCenter,
  deleteAccount,
  accountStatement,
  preferences,
  myProfile,
  notificationPreferences,
  accessibilityPreferences,
  linkedBanks,
  loans,
  cards,
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
  /// [UnavailableRouteScreen].
  const AppRouteDefinition.unavailable(
    UnavailableDestination this.unavailable, {
    this.isPublic = false,
  }) : screen = null,
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

  /// Builds this route's standalone page, or null for a flow screen.
  Widget Function()? get pageBuilder {
    final destination = unavailable;
    if (destination != null) {
      return () => UnavailableRouteScreen(destination: destination);
    }
    return page;
  }
}

/// The single route registry. [AppRoutes.allRoutes], [AppRoutes.publicRoutes]
/// and [appScreenForRoute] are all derived from it.
///
/// Public routes: entry, sign-in and recovery, first-PIN setup (which needs a
/// session but no PIN yet), and static support and legal pages that hold no
/// customer data.
const appRouteDefinitions = <String, AppRouteDefinition>{
  // Entry, sign-in and recovery.
  AppRoutes.bootstrap: AppRouteDefinition.page(
    BootstrapScreen.new,
    isPublic: true,
  ),
  AppRoutes.onboarding: AppRouteDefinition.page(
    OnboardingScreen.new,
    isPublic: true,
  ),
  AppRoutes.verificationMethod: AppRouteDefinition.page(
    VerifyMethodScreen.new,
    isPublic: true,
  ),
  AppRoutes.otp: AppRouteDefinition.page(SignupOtpScreen.new, isPublic: true),
  AppRoutes.createPassword: AppRouteDefinition.page(
    CreatePasswordScreen.new,
    isPublic: true,
  ),
  AppRoutes.login: AppRouteDefinition.page(LoginScreen.new, isPublic: true),
  AppRoutes.biometricLogin: AppRouteDefinition.page(
    LoginScreen.new,
    isPublic: true,
  ),
  AppRoutes.passwordReset: AppRouteDefinition.page(
    PasswordResetScreen.new,
    isPublic: true,
  ),
  AppRoutes.newDeviceOtp: AppRouteDefinition.page(
    NewDeviceOtpScreen.new,
    isPublic: true,
  ),
  AppRoutes.createFirstPin: AppRouteDefinition.page(
    CreateFirstPinScreen.new,
    isPublic: true,
  ),

  AppRoutes.home: AppRouteDefinition.page(HomeScreen.new),

  // Savings.
  AppRoutes.savingsHub: AppRouteDefinition.page(SaveHubScreen.new),
  AppRoutes.flexSave: AppRouteDefinition.page(FlexScreen.new),
  AppRoutes.flexTopUp: AppRouteDefinition.page(AddMoneyScreen.new),
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
  AppRoutes.targetSave: AppRouteDefinition.page(SavingsProductScreen.target),
  AppRoutes.targetSaveCreate: AppRouteDefinition.page(
    PlanCreationScreen.smartSave,
  ),
  AppRoutes.targetSort: AppRouteDefinition.unavailable(savingsPlansUnavailable),
  AppRoutes.lockSave: AppRouteDefinition.page(SavingsProductScreen.lock),
  AppRoutes.lockCreate: AppRouteDefinition.page(PlanCreationScreen.fixed),
  AppRoutes.lockDetails: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.lockAddMoney: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupSave: AppRouteDefinition.page(SavingsProductScreen.group),
  AppRoutes.groupCreate: AppRouteDefinition.page(PlanCreationScreen.padi),
  AppRoutes.groupContribute: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupInvite: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.groupMembers: AppRouteDefinition.unavailable(
    savingsPlansUnavailable,
  ),
  AppRoutes.savingsPlanDetail: AppRouteDefinition.page(
    SavingsPlanDetailScreen.new,
  ),

  // Funding.
  AppRoutes.addMoney: AppRouteDefinition.page(AddMoneyScreen.new),
  AppRoutes.bankTransferFunding: AppRouteDefinition.page(AddMoneyScreen.new),
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
  AppRoutes.sendHub: AppRouteDefinition.page(SendScreen.hub),
  AppRoutes.sendOwnAccount: AppRouteDefinition.page(SendScreen.ownAccount),
  AppRoutes.sendBeneficiary: AppRouteDefinition.page(SendScreen.beneficiary),
  AppRoutes.sendOtherBank: AppRouteDefinition.page(SendScreen.otherBank),

  // Payments.
  AppRoutes.paymentsHub: AppRouteDefinition.page(PaymentsScreen.hub),
  AppRoutes.airtime: AppRouteDefinition.page(PaymentsScreen.airtime),
  AppRoutes.data: AppRouteDefinition.page(PaymentsScreen.data),
  AppRoutes.billerListElectricity: AppRouteDefinition.page(
    PaymentsScreen.billers,
  ),
  AppRoutes.billerListWater: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.billerListCable: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.billerListInternet: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.billerListEducation: AppRouteDefinition.page(
    PaymentsScreen.billers,
  ),
  AppRoutes.billerListMore: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.billPay: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.scanToPay: AppRouteDefinition.page(PaymentsScreen.scan),
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
  AppRoutes.tierOverview: AppRouteDefinition.page(KycTiersScreen.new),
  // Compatibility routes: both open the identity screen, preselecting the
  // identity type rather than standing for a whole tier.
  AppRoutes.tier1Bvn: AppRouteDefinition.page(KycIdentityScreen.new),
  AppRoutes.tier2Nin: AppRouteDefinition.page(KycIdentityScreen.new),
  AppRoutes.governmentIdVerification: AppRouteDefinition.page(
    KycGovernmentIdScreen.new,
  ),
  AppRoutes.nextOfKin: AppRouteDefinition.page(NextOfKinScreen.new),
  AppRoutes.tier3Address: AppRouteDefinition.page(KycUtilityBillScreen.new),
  AppRoutes.kycCacDocument: AppRouteDefinition.page(KycDocumentScreen.cac),
  AppRoutes.kycBankStatement: AppRouteDefinition.page(
    KycDocumentScreen.bankStatement,
  ),
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
  // Live history once its capability is on; until then, unavailable.
  AppRoutes.transactionHistory: AppRouteDefinition.page(SendScreen.history),
  AppRoutes.transactionDetail: AppRouteDefinition.page(SendScreen.detail),
  AppRoutes.transactionAuthorization: AppRouteDefinition.page(
    SendScreen.authorize,
  ),
  AppRoutes.receipt: AppRouteDefinition.page(SendScreen.receipt),
};

AppScreen appScreenForRoute(String? routeName) =>
    appRouteDefinitions[routeName]?.screen ?? AppScreen.account;

/// The hub route for a bottom-navigation section, for screens outside the
/// flow.
String appRouteForSection(AppSection section) => switch (section) {
  AppSection.home => AppRoutes.home,
  AppSection.save => AppRoutes.savingsHub,
  AppSection.send => AppRoutes.sendHub,
  AppSection.payments => AppRoutes.paymentsHub,
  AppSection.account => AppRoutes.account,
};
