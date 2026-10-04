part of '../app_flow/app_flow_navigator.dart';

/// A registered route whose feature is not built yet.
///
/// The page explains the gap and nothing else: no sample balances, rows,
/// contacts, or legal text that could be read as real.
class UnavailableDestination {
  const UnavailableDestination({
    required this.title,
    required this.heading,
    required this.message,
    required this.section,
    this.capability,
  });

  final String title;
  final String heading;
  final String message;
  final AppSection section;

  /// The registry entry this page stands in for, when one exists.
  final FeatureCapability? capability;
}

const _savingsPlansUnavailable = UnavailableDestination(
  title: 'Savings plans',
  heading: 'Unavailable',
  message: 'Savings plans are not available yet.',
  section: AppSection.save,
  capability: FeatureCapability.savingsPlansView,
);

/// Published contact details, the same ones Account lists.
const _supportContactMessage =
    'Call customer care on +234 906 464 1439 or 0703 973 9086, or email '
    'info@boctrustmfb.com.';

const _supportUnavailable = UnavailableDestination(
  title: 'Support',
  heading: 'In-app support is unavailable',
  message: _supportContactMessage,
  section: AppSection.account,
);

const _socialUnavailable = UnavailableDestination(
  title: 'Social links',
  heading: 'Social profiles are unavailable',
  message: 'BOCTRUST social profiles are not available in the app yet.',
  section: AppSection.account,
);

/// Shown if a preview screen is built without a route it recognises.
const unknownUnavailableDestination = UnavailableDestination(
  title: 'Unavailable',
  heading: 'Unavailable',
  message: 'This page is not available yet.',
  section: AppSection.home,
);

/// Every registered route that renders [UnavailableFeatureScreen].
const unavailableDestinations = <String, UnavailableDestination>{
  AppRoutes.newSavingsChooser: _savingsPlansUnavailable,
  AppRoutes.targetSort: _savingsPlansUnavailable,
  AppRoutes.lockDetails: _savingsPlansUnavailable,
  AppRoutes.lockAddMoney: _savingsPlansUnavailable,
  AppRoutes.groupContribute: _savingsPlansUnavailable,
  AppRoutes.groupInvite: _savingsPlansUnavailable,
  AppRoutes.groupMembers: _savingsPlansUnavailable,
  AppRoutes.flexWithdraw: UnavailableDestination(
    title: 'Withdrawals',
    heading: 'Unavailable',
    message: 'Withdrawals are not available yet.',
    section: AppSection.save,
    capability: FeatureCapability.flexWithdraw,
  ),
  AppRoutes.flexStatement: UnavailableDestination(
    title: 'Savings statements',
    heading: 'Unavailable',
    message: 'Savings statements are not available yet.',
    section: AppSection.save,
    capability: FeatureCapability.flexStatement,
  ),
  AppRoutes.flexSettings: UnavailableDestination(
    title: 'Auto-save',
    heading: 'Unavailable',
    message: 'Auto-save is not available yet.',
    section: AppSection.save,
    capability: FeatureCapability.flexAutoSave,
  ),
  AppRoutes.cardFunding: UnavailableDestination(
    title: 'Card funding',
    heading: 'Unavailable',
    message: 'Card funding is not available yet.',
    section: AppSection.save,
    capability: FeatureCapability.cardFunding,
  ),
  AppRoutes.paymentWebView: UnavailableDestination(
    title: 'Payment',
    heading: 'Payment checkout is unavailable',
    message: 'Card and hosted checkout payments are not available yet.',
    section: AppSection.payments,
    capability: FeatureCapability.cardFunding,
  ),
  AppRoutes.manageBeneficiaries: UnavailableDestination(
    title: 'Beneficiaries',
    heading: 'Beneficiaries are unavailable',
    message: 'Saved beneficiaries are not available yet.',
    section: AppSection.account,
    capability: FeatureCapability.beneficiaries,
  ),
  // Shown only while the capability is off; otherwise the route opens the
  // live history screen.
  AppRoutes.transactionHistory: UnavailableDestination(
    title: 'Transactions',
    heading: 'Transaction history is unavailable',
    message: 'Your transaction history cannot be displayed yet.',
    section: AppSection.payments,
    capability: FeatureCapability.transactionHistory,
  ),
  AppRoutes.support: _supportUnavailable,
  AppRoutes.supportCall: _supportUnavailable,
  AppRoutes.supportEmail: _supportUnavailable,
  AppRoutes.supportChat: UnavailableDestination(
    title: 'Chat with support',
    heading: 'In-app chat is unavailable',
    message: _supportContactMessage,
    section: AppSection.account,
  ),
  // No policy-content endpoint and no bundled copy exist.
  AppRoutes.privacyPolicy: UnavailableDestination(
    title: 'Privacy Policy',
    heading: 'The privacy policy is unavailable',
    message: 'The privacy policy is not available in the app yet.',
    section: AppSection.account,
  ),
  AppRoutes.terms: UnavailableDestination(
    title: 'Terms & Conditions',
    heading: 'The terms and conditions are unavailable',
    message: 'The terms and conditions are not available in the app yet.',
    section: AppSection.account,
  ),
  // Official handles have not been supplied.
  AppRoutes.socialFacebook: _socialUnavailable,
  AppRoutes.socialX: _socialUnavailable,
  AppRoutes.socialLinkedIn: _socialUnavailable,
};

class UnavailableFeatureScreen extends StatelessWidget {
  const UnavailableFeatureScreen({
    required this.destination,
    required this.onBack,
    required this.onSectionSelected,
    this.action,
    super.key,
  });

  final UnavailableDestination destination;
  final VoidCallback onBack;
  final ValueChanged<AppSection> onSectionSelected;

  /// An optional way out, such as returning to the section hub.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    return AppScaffold(
      title: destination.title,
      activeSection: destination.section,
      onBack: onBack,
      onSectionSelected: onSectionSelected,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          ApiStateCard(
            title: destination.heading,
            message: destination.message,
            tone: ApiStateTone.blocked,
          ),
          if (action != null) ...[const SizedBox(height: 16), action],
        ],
      ),
    );
  }
}
