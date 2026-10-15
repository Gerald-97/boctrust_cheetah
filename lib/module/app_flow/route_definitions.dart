part of 'app_ui.dart';

enum AppSection { home, save, send, payments, account }

/// What a registered route opens and whether it needs a session.
class AppRouteDefinition {
  /// A screen built by [page].
  const AppRouteDefinition.page(
    Widget Function() this.page, {
    this.isPublic = false,
  }) : unavailable = null;

  /// A route with no working feature yet, rendered by
  /// [UnavailableRouteScreen].
  const AppRouteDefinition.unavailable(
    UnavailableDestination this.unavailable, {
    this.isPublic = false,
  }) : page = null;

  final Widget Function()? page;
  final UnavailableDestination? unavailable;

  /// Reachable without a signed-in session. Every other route needs a session
  /// and a created PIN.
  final bool isPublic;

  /// Builds this route's page.
  Widget Function() get pageBuilder {
    final destination = unavailable;
    if (destination != null) {
      return () => UnavailableRouteScreen(destination: destination);
    }
    return page!;
  }
}

/// The single route registry. [AppRoutes.allRoutes] and
/// [AppRoutes.publicRoutes] are derived from it.
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

  AppRoutes.home: AppRouteDefinition.page(SectionShell.home),

  // Savings.
  AppRoutes.savingsHub: AppRouteDefinition.page(SectionShell.save),
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
  AppRoutes.flexStatement: AppRouteDefinition.page(
    BankAccountDetailScreen.flex,
  ),
  AppRoutes.bankAccountDetail: AppRouteDefinition.page(
    BankAccountDetailScreen.new,
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
  AppRoutes.interestHistory: AppRouteDefinition.page(InterestHistoryScreen.new),

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
  AppRoutes.sendHub: AppRouteDefinition.page(SectionShell.send),
  AppRoutes.sendOwnAccount: AppRouteDefinition.page(SendScreen.ownAccount),
  AppRoutes.sendBeneficiary: AppRouteDefinition.page(SendScreen.beneficiary),
  AppRoutes.sendOtherBank: AppRouteDefinition.page(SendScreen.otherBank),
  AppRoutes.scanToPay: AppRouteDefinition.page(SendScreen.scan),

  // Payments.
  AppRoutes.paymentsHub: AppRouteDefinition.page(SectionShell.payments),
  AppRoutes.airtime: AppRouteDefinition.page(PaymentsScreen.airtime),
  AppRoutes.data: AppRouteDefinition.page(PaymentsScreen.data),
  AppRoutes.billerListElectricity: AppRouteDefinition.page(
    PaymentsScreen.electricity,
  ),
  AppRoutes.billerListWater: AppRouteDefinition.page(PaymentsScreen.water),
  AppRoutes.billerListCable: AppRouteDefinition.page(PaymentsScreen.cableTv),
  AppRoutes.billerListInternet: AppRouteDefinition.page(
    PaymentsScreen.internet,
  ),
  AppRoutes.billerListEducation: AppRouteDefinition.page(
    PaymentsScreen.education,
  ),
  AppRoutes.billerListMore: AppRouteDefinition.page(PaymentsScreen.billers),
  AppRoutes.billerSearch: AppRouteDefinition.page(PaymentsScreen.search),
  AppRoutes.billPay: AppRouteDefinition.page(PaymentsScreen.billers),
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
  AppRoutes.account: AppRouteDefinition.page(SectionShell.account),
  AppRoutes.tierOverview: AppRouteDefinition.page(KycTiersScreen.new),
  AppRoutes.transactionLimits: AppRouteDefinition.page(
    TransactionLimitsScreen.new,
  ),
  // Compatibility routes: both open the identity screen, preselecting the
  // identity type rather than standing for a whole tier.
  AppRoutes.tier1Bvn: AppRouteDefinition.page(KycIdentityScreen.new),
  AppRoutes.tier2Nin: AppRouteDefinition.page(KycIdentityScreen.new),
  AppRoutes.governmentIdVerification: AppRouteDefinition.page(
    KycGovernmentIdScreen.new,
  ),
  AppRoutes.nextOfKin: AppRouteDefinition.page(NextOfKinScreen.new),
  AppRoutes.tier3Address: AppRouteDefinition.page(KycUtilityBillScreen.new),
  AppRoutes.manageBeneficiaries: AppRouteDefinition.page(
    BeneficiariesScreen.new,
  ),
  AppRoutes.linkedBanks: AppRouteDefinition.page(AccountScreen.linkedBanks),
  AppRoutes.securitySettings: AppRouteDefinition.page(
    AccountScreen.securityCenter,
  ),
  AppRoutes.deleteAccount: AppRouteDefinition.page(AccountScreen.deleteAccount),
  AppRoutes.accountStatement: AppRouteDefinition.page(
    AccountScreen.accountStatement,
  ),
  AppRoutes.myProfile: AppRouteDefinition.page(AccountScreen.myProfile),
  AppRoutes.preferences: AppRouteDefinition.page(AccountScreen.preferences),
  AppRoutes.notificationPreferences: AppRouteDefinition.page(
    AccountScreen.notificationPreferences,
  ),
  AppRoutes.accessibilityPreferences: AppRouteDefinition.page(
    AccountScreen.accessibilityPreferences,
  ),
  // Preferences holds the theme picker.
  AppRoutes.themeSettings: AppRouteDefinition.page(AccountScreen.preferences),
  AppRoutes.loansComingSoon: AppRouteDefinition.page(AccountScreen.loans),
  AppRoutes.loansNotifyMe: AppRouteDefinition.page(AccountScreen.loans),
  AppRoutes.cardsComingSoon: AppRouteDefinition.page(AccountScreen.cards),
  AppRoutes.cardsNotifyMe: AppRouteDefinition.page(AccountScreen.cards),

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
  AppRoutes.privacyPolicy: AppRouteDefinition.page(
    LegalDocumentScreen.privacy,
    isPublic: true,
  ),
  AppRoutes.terms: AppRouteDefinition.page(
    LegalDocumentScreen.terms,
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

/// The hub route for a bottom-navigation section.
String appRouteForSection(AppSection section) => switch (section) {
  AppSection.home => AppRoutes.home,
  AppSection.save => AppRoutes.savingsHub,
  AppSection.send => AppRoutes.sendHub,
  AppSection.payments => AppRoutes.paymentsHub,
  AppSection.account => AppRoutes.account,
};

/// The section whose hub [route] is, or null for any other route.
AppSection? sectionForRoute(String route) => AppSection.values
    .where((section) => appRouteForSection(section) == route)
    .firstOrNull;

/// Switches to a bottom-navigation section.
///
/// On a hub, the shell selects the section in place. On a page above a
/// shell, the pages above it are dropped first, so tabs never stack. A page
/// with no shell beneath is replaced by one.
void replaceWithSection(BuildContext context, AppSection section) {
  final scope = _SectionShellScope.maybeOf(context);
  if (scope != null) {
    scope.select(section);
    return;
  }
  if (!selectOpenSection(section)) {
    Navigator.of(context).pushReplacementNamed(appRouteForSection(section));
  }
}

/// Shows [section] in the topmost open [SectionShell], dropping the pages
/// above it. False when no shell is open, or when [dropPages] is false and
/// pages are open above the shell.
bool selectOpenSection(AppSection section, {bool dropPages = true}) {
  final shell = _SectionShellState._open
      .where((shell) => shell._route?.isActive ?? false)
      .lastOrNull;
  final route = shell?._route;
  final navigator = route?.navigator;
  if (shell == null || navigator == null) return false;
  if (!dropPages && !route!.isCurrent) return false;
  navigator.popUntil((candidate) => candidate == route);
  shell._select(section);
  return true;
}
