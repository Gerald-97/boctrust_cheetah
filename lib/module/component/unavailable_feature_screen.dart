part of '../app_flow/app_ui.dart';

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

const savingsPlansUnavailable = UnavailableDestination(
  title: 'Savings plans',
  heading: 'Unavailable',
  message: 'Savings plans are not available yet.',
  section: AppSection.save,
  capability: FeatureCapability.savingsPlansView,
);

/// Published contact details, the same ones Account lists.
const supportContactMessage =
    'Call customer care on +234 906 464 1439 or 0703 973 9086, or email '
    'info@boctrustmfb.com.';

const supportUnavailable = UnavailableDestination(
  title: 'Support',
  heading: 'In-app support is unavailable',
  message: supportContactMessage,
  section: AppSection.account,
);

const socialUnavailable = UnavailableDestination(
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
