import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../module/app_flow/app_ui.dart';
import 'route_arguments.dart';
import 'route_message_scope.dart';

class AppRoutes {
  const AppRoutes._();

  static const initial = bootstrap;
  static const bootstrap = '/bootstrap';
  static const onboarding = '/onboarding';
  static const verificationMethod = '/onboarding/verification-method';
  static const otp = '/onboarding/otp';
  static const createPassword = '/onboarding/create-password';
  static const login = '/login';
  static const biometricLogin = '/login/biometric';
  static const passwordReset = '/login/password-reset';
  static const newDeviceOtp = '/login/new-device-otp';
  static const createFirstPin = '/onboarding/create-pin';
  static const home = '/home';
  static const savingsHub = '/savings';
  static const newSavingsChooser = '/savings/new';
  static const flexSave = '/savings/flex';
  static const flexTopUp = '/savings/flex/top-up';
  static const flexWithdraw = '/savings/flex/withdraw';
  static const flexStatement = '/savings/flex/statement';
  static const flexSettings = '/savings/flex/settings';
  static const targetSave = '/savings/target';
  static const targetSaveCreate = '/savings/target/create';
  static const targetSort = '/savings/target/sort';
  static const lockSave = '/savings/lock';
  static const lockCreate = '/savings/lock/create';
  static const lockDetails = '/savings/lock/details';
  static const lockAddMoney = '/savings/lock/add-money';
  static const groupSave = '/savings/group';
  static const groupCreate = '/savings/group/create';
  static const groupContribute = '/savings/group/contribute';
  static const groupInvite = '/savings/group/invite';
  static const groupMembers = '/savings/group/members';
  static const savingsPlanDetail = '/savings/plan';
  static const bankAccountDetail = '/savings/account';
  static const addMoney = '/wallet/add-money';
  static const bankTransferFunding = '/wallet/bank-transfer';
  static const cardFunding = '/wallet/card';
  static const sendHub = '/send';
  static const sendOwnAccount = '/send/own-account';
  static const sendBeneficiary = '/send/beneficiary';
  static const sendOtherBank = '/send/other-bank';
  static const scanToPay = '/send/scan-to-pay';
  static const paymentsHub = '/payments';
  static const airtime = '/payments/airtime';
  static const data = '/payments/data';
  static const billerListElectricity = '/payments/billers/electricity';
  static const billerListWater = '/payments/billers/water';
  static const billerListCable = '/payments/billers/cable';
  static const billerListInternet = '/payments/billers/internet';
  static const billerListEducation = '/payments/billers/education';
  static const billerListMore = '/payments/billers/more';
  static const billPay = '/payments/bill-pay';
  static const account = '/account';
  static const tierOverview = '/account/tier';
  static const tier1Bvn = '/account/tier/bvn';
  static const tier2Nin = '/account/tier/nin';
  static const governmentIdVerification = '/account/tier/government-id';
  static const nextOfKin = '/account/tier/next-of-kin';
  static const tier3Address = '/account/tier/address';
  static const manageBeneficiaries = '/account/beneficiaries';
  static const linkedBanks = '/account/linked-banks';
  static const securitySettings = '/account/security';
  static const deleteAccount = '/account/delete';
  static const accountStatement = '/account/statement';
  static const myProfile = '/account/profile';
  static const preferences = '/account/preferences';
  static const notificationPreferences = '/account/preferences/notifications';
  static const accessibilityPreferences = '/account/preferences/accessibility';
  static const support = '/account/support';
  static const supportChat = '/account/support/chat';
  static const supportCall = '/account/support/call';
  static const supportEmail = '/account/support/email';
  static const privacyPolicy = '/account/legal/privacy';
  static const terms = '/account/legal/terms';
  static const socialFacebook = '/account/social/facebook';
  static const socialX = '/account/social/x';
  static const socialLinkedIn = '/account/social/linkedin';
  static const themeSettings = '/account/theme';
  static const loansComingSoon = '/account/loans';
  static const loansNotifyMe = '/account/loans/notify-me';
  static const cardsComingSoon = '/account/cards';
  static const cardsNotifyMe = '/account/cards/notify-me';
  static const notifications = '/notifications';
  static const transactionHistory = '/transactions';
  static const transactionDetail = '/transactions/detail';
  static const transactionAuthorization = '/transaction/authorize';
  static const receipt = '/transaction/receipt';
  static const paymentWebView = '/payment/webview';

  /// Derived from [appRouteDefinitions], the single route registry.
  static final allRoutes = appRouteDefinitions.keys.toSet();
  static final publicRoutes = {
    for (final MapEntry(:key, :value) in appRouteDefinitions.entries)
      if (value.isPublic) key,
  };
  static final privateRoutes = allRoutes.difference(publicRoutes);
}

class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = _pageFor(settings);
    return _appRoute(settings: settings, page: page);
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _appRoute(
      settings: settings,
      page: const _RouteFallbackScreen(
        title: 'Route unavailable',
        description: 'This route is not registered yet.',
      ),
    );
  }

  static Route<dynamic> _appRoute({
    required RouteSettings settings,
    required Widget page,
  }) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final offset = Tween<Offset>(
          begin: const Offset(.06, 0),
          end: Offset.zero,
        ).animate(curved);
        final fade = Tween<double>(begin: 0, end: 1).animate(curved);
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(position: offset, child: child),
        );
      },
    );
  }

  static Widget _pageFor(RouteSettings settings) {
    final name = settings.name;
    final definition = appRouteDefinitions[name];
    if (name != null && definition != null) {
      final arguments = settings.arguments is AppRouteArguments
          ? settings.arguments! as AppRouteArguments
          : const AppRouteArguments();
      final screen = RouteMessageScope(
        arguments: arguments,
        child: definition.pageBuilder(),
      );
      return AppRoutes.privateRoutes.contains(name)
          ? PrivateRouteGate(routeName: name, child: screen)
          : screen;
    }

    return _placeholder(settings.name ?? 'Unknown route');
  }

  static Widget _placeholder(String route) {
    final title = route
        .split('/')
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).replaceAll('-', ' ')}',
        )
        .join(' • ');
    return _RouteFallbackScreen(
      title: title.isEmpty ? 'BOCTRUST' : title,
      description: 'This route is not registered in the app route map.',
    );
  }
}

class _RouteFallbackScreen extends StatelessWidget {
  const _RouteFallbackScreen({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(IconsaxPlusLinear.setting_2, size: 56),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(description, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
