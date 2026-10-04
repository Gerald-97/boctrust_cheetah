import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app/app_router.dart';
import '../../app/boc_icons.dart';
import '../../app/auth_navigation_provider.dart';
import '../../app/feature_capability.dart';
import '../../app/response_handler.dart';
import '../../app/route_arguments.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../utils/validators.dart' as validators;
import '../account/model/user_profile_model.dart';
import '../account/model/account_preferences.dart';
import '../account/provider/account_deletion_provider.dart';
import '../account/provider/account_preferences_provider.dart';
import '../account/provider/user_providers.dart';
import '../account/model/withdrawal_bank_models.dart';
import '../account/provider/withdrawal_bank_providers.dart';
import '../home/model/user_home_model.dart';
import '../home/provider/home_provider.dart';
import '../send/model/transaction_models.dart';
import '../kyc/model/kyc_contact_requirement.dart';
import '../kyc/screens/kyc_screens.dart';
import '../account/screens/contact_verification.dart';
import '../home/screens/home_screen.dart';
import '../notifications/screens/notifications_screen.dart';
import 'flow_page.dart';
import '../payments/screens/payments_screens.dart';
import '../send/screens/send_screens.dart';
import '../savings/screens/savings_screens.dart';
import '../onboarding/screens/auth_widgets.dart';
import '../onboarding/screens/login_screens.dart';
import '../onboarding/screens/recovery_screens.dart';
import '../onboarding/screens/signup_screens.dart';
import '../onboarding/screens/startup_screens.dart';
import '../component/text_fields.dart';
import '../component/password_strength_component.dart';
import '../onboarding/model/auth_enums.dart';
import '../onboarding/model/auth_flow_models.dart';
import '../onboarding/model/remembered_biometric_profile.dart';
import '../onboarding/provider/auth_session_provider.dart';
import '../onboarding/provider/biometric_login_provider.dart';
import '../onboarding/provider/recovery_providers.dart';
import '../onboarding/provider/security_action_providers.dart';
import '../onboarding/provider/test_otp_provider.dart';

part 'app_flow_screens.dart';

part '../component/branding.dart';

part '../component/app_scaffold.dart';
part '../component/responsive_layout.dart';
part '../component/app_action_sheet.dart';

part '../component/buttons.dart';

part '../component/cards.dart';

part '../component/forms.dart';

part '../component/kyc_widgets.dart';

part '../component/list_tiles.dart';

part '../component/money_widgets.dart';

part '../component/payment_widgets.dart';

part '../component/savings_widgets.dart';

part '../component/misc_widgets.dart';

part '../component/api_state_widgets.dart';

part '../component/private_route_gate.dart';

part '../component/flow_widgets.dart';

part '../component/transaction_widgets.dart';
part '../component/unavailable_feature_screen.dart';

part '../savings/screens/savings_access_gate.dart';

part '../account/screens/account_screens.dart';
part '../account/screens/linked_bank_accounts_screen.dart';
part '../account/screens/account_control_screens.dart';

class AppFlowRouteScreen extends StatelessWidget {
  const AppFlowRouteScreen({
    super.key,
    required this.initialScreen,
    this.initialRouteName,
    this.routeArguments = const AppRouteArguments(),
  });

  final AppScreen initialScreen;
  final String? initialRouteName;
  final AppRouteArguments routeArguments;

  @override
  Widget build(BuildContext context) {
    return AppFlowNavigator(
      initialScreen: initialScreen,
      initialRouteName: initialRouteName,
      routeArguments: routeArguments,
    );
  }
}

class AppFlowNavigator extends ConsumerStatefulWidget {
  const AppFlowNavigator({
    this.initialScreen = AppScreen.account,
    this.initialRouteName,
    this.routeArguments = const AppRouteArguments(),
    super.key,
  });

  final AppScreen initialScreen;
  final String? initialRouteName;
  final AppRouteArguments routeArguments;

  @override
  ConsumerState<AppFlowNavigator> createState() => AppFlowNavigatorState();
}

class AppFlowNavigatorState extends ConsumerState<AppFlowNavigator> {
  late AppScreen _screen = widget.initialScreen;
  final List<AppScreen> _history = <AppScreen>[];

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _currentSecretController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final message = widget.routeArguments.message;
    if (message != null && message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.routeArguments.messageTone) {
          case AppMessageTone.info:
            _showMessage(message);
          case AppMessageTone.success:
            _showSuccessMessage(message);
          case AppMessageTone.error:
            _showErrorMessage(message);
        }
      });
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _currentSecretController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _go(AppScreen next, {bool replace = false}) {
    setState(() {
      if (!replace) _history.add(_screen);
      _screen = next;
    });
  }

  void _back() {
    if (_history.isNotEmpty) {
      setState(() {
        _screen = _history.removeLast();
      });
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
  }

  /// A tab replaces this page with the section hub.
  void _goSection(AppSection section) =>
      Navigator.of(context).pushReplacementNamed(appRouteForSection(section));

  /// A placeholder screen may only stand in for a capability the registry
  /// still reports in [expected].
  void _assertPlaceholderFor(
    FeatureCapability capability,
    FeatureAvailability expected,
  ) {
    assert(
      ref.read(featureAvailabilityProvider(capability)) == expected,
      '$capability is no longer $expected but still shows a placeholder.',
    );
  }

  void _showMessage(String message) {
    ResponseHandler.showInfo(message);
  }

  void _showSuccessMessage(String message) {
    ResponseHandler.showSuccess(message);
  }

  void _showErrorMessage(String message) {
    ResponseHandler.showError(message);
  }

  void refreshAuthFormState(VoidCallback update) {
    setState(update);
  }

  Future<void> _confirmSignOut() => confirmSignOut(context, ref);

  Future<void> _openAuthDestination(
    AuthDestination destination, {
    AuthNavigationMode mode = AuthNavigationMode.push,
  }) => openAuthDestination(ref, destination, mode: mode);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: _buildScreen(_screen),
    );
  }

  Widget _buildScreen(AppScreen screen) {
    switch (screen) {
      case AppScreen.securityCenter:
        return _securityCenterScreen();
      case AppScreen.deleteAccount:
        return _deleteAccountScreen();
      case AppScreen.accountStatement:
        return _accountStatementScreen();
      case AppScreen.myProfile:
        return _myProfileScreen();
      case AppScreen.preferences:
        return _preferencesScreen();
      case AppScreen.notificationPreferences:
        return _notificationPreferencesScreen();
      case AppScreen.accessibilityPreferences:
        return _accessibilityPreferencesScreen();
      case AppScreen.linkedBanks:
        return _linkedBankAccountsScreen();
      case AppScreen.loans:
        return _comingSoonScreen(
          capability: FeatureCapability.loans,
          title: 'Loans',
          icon: IconsaxPlusLinear.percentage_circle,
          message:
              "Loans aren't part of the BOCTRUST app yet — this release is focused on Savings.",
        );
      case AppScreen.cards:
        return _comingSoonScreen(
          capability: FeatureCapability.cards,
          title: 'Cards',
          icon: IconsaxPlusLinear.card,
          message:
              "Virtual and physical debit cards aren't part of the BOCTRUST app yet. This release is focused on Savings.",
        );
      case AppScreen.account:
        return _accountScreen();
    }
  }
}
