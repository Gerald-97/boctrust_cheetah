import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../app/api_logger.dart';
import '../../app/auth_navigation_provider.dart';
import '../../app/bootstrap_provider.dart';
import '../../app/preferences.dart';
import '../../app/response_handler.dart';
import '../../app/route_arguments.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../utils/auth_input.dart';
import '../../utils/utils.dart';
import '../../utils/validators.dart' as validators;
import '../account/model/user_tier_model.dart';
import '../account/provider/user_providers.dart';
import '../home/model/user_home_model.dart';
import '../home/provider/home_provider.dart';
import '../component/text_fields.dart';
import '../component/password_strength_component.dart';
import '../onboarding/model/auth_enums.dart';
import '../onboarding/model/auth_flow_models.dart';
import '../onboarding/provider/auth_session_provider.dart';
import '../onboarding/provider/identifier_verification_provider.dart';
import '../onboarding/provider/login_flow_provider.dart';
import '../onboarding/provider/recovery_providers.dart';
import '../onboarding/provider/security_action_providers.dart';
import '../onboarding/provider/signup_flow_provider.dart';
import '../onboarding/provider/test_otp_provider.dart';

part 'app_flow_screens.dart';

part '../data/transaction_context.dart';

part '../data/billers.dart';

part '../component/branding.dart';

part '../component/app_scaffold.dart';

part '../component/buttons.dart';

part '../component/cards.dart';

part '../component/forms.dart';

part '../component/kyc_widgets.dart';

part '../component/list_tiles.dart';

part '../component/money_widgets.dart';

part '../component/payment_widgets.dart';

part '../component/savings_widgets.dart';

part '../component/notification_widgets.dart';

part '../component/misc_widgets.dart';

part '../component/api_state_widgets.dart';

part '../onboarding/screens/onboarding_flow_screens.dart';

part '../account/screens/kyc_screens.dart';

part '../home/screens/home_screen.dart';

part '../savings/screens/savings_screens.dart';

part '../send/screens/send_screens.dart';

part '../payments/screens/payments_screens.dart';

part '../notifications/screens/notifications_screen.dart';

part '../account/screens/account_screens.dart';

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
    this.initialScreen = AppScreen.bootstrap,
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
  int _onboardingIndex = 0;
  bool _verifyByPhone = true;
  PhoneVerificationChannel _phoneChannel = PhoneVerificationChannel.sms;
  int _authPinCount = 0;
  String _selectedBillerCategory = 'electricity';
  BillerItem _selectedBiller = const BillerItem(
    'Eko Electricity Distribution Co. (EKEDC)',
    'Lagos — Eko & environs',
  );
  TransactionContext _transaction = const TransactionContext(
    amount: '₦35,000.00',
    description: 'Sent to Ifeoma Nwachukwu · Cheetah.',
    title: 'Transfer successful',
    row1Label: 'Recipient',
    row1Value: 'Ifeoma Nwachukwu',
    row2Label: 'Account',
    row2Value: '0198 220 341',
  );

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _currentSecretController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _createPasswordFormKey = GlobalKey<FormState>();
  final _passwordResetFormKey = GlobalKey<FormState>();
  final _createFirstPinFormKey = GlobalKey<FormState>();
  AutovalidateMode _createPasswordAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _passwordResetAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _createFirstPinAutovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _selectedBillerCategory =
        billerCategoryForRoute(widget.initialRouteName) ??
        _selectedBillerCategory;
    _selectedBiller =
        billerCategories[_selectedBillerCategory]?.items.first ??
        _selectedBiller;
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
    _currentSecretController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _go(AppScreen next, {bool replace = false}) {
    setState(() {
      if (!replace) _history.add(_screen);
      _screen = next;
      if (next == AppScreen.authPin) _authPinCount = 0;
    });
  }

  void _back() {
    _cancelFlowForScreen(_screen);
    if (_history.isEmpty) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      return;
    }
    setState(() {
      _screen = _history.removeLast();
    });
  }

  void _cancelFlowForScreen(AppScreen screen) {
    if (screen == AppScreen.passwordReset) {
      ref.read(passwordRecoveryProvider.notifier).cancel();
    }
  }

  void _goSection(AppSection section) {
    final target = switch (section) {
      AppSection.home => AppScreen.home,
      AppSection.save => AppScreen.saveHub,
      AppSection.send => AppScreen.sendHub,
      AppSection.payments => AppScreen.payments,
      AppSection.account => AppScreen.account,
    };
    _go(target, replace: true);
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

  Future<void> _confirmSignOut() async {
    if (ref.read(logoutProvider).isLoading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to log in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(logoutProvider.notifier).logout();
    }
  }

  void _openAuth(TransactionContext transaction) {
    _transaction = transaction;
    _go(AppScreen.authPin);
  }

  void _selectBiller(String categoryKey, BillerItem item) {
    setState(() {
      _selectedBillerCategory = categoryKey;
      _selectedBiller = item;
    });
    _go(AppScreen.billPay);
  }

  void _pinPressed() {
    if (_authPinCount >= 4) return;
    setState(() => _authPinCount += 1);
    if (_authPinCount == 4) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _go(AppScreen.success);
      });
    }
  }

  void _selectOnboardingIndex(int index) {
    setState(() => _onboardingIndex = index);
  }

  void _advanceOnboarding() {
    if (_onboardingIndex < 2) {
      setState(() => _onboardingIndex += 1);
      return;
    }
    _openAuthDestination(AuthDestination.verificationMethod);
  }

  void _selectVerificationMethod({required bool phone}) {
    setState(() {
      _verifyByPhone = phone;
      _identifierController.clear();
    });
  }

  Future<void> _openAuthDestination(
    AuthDestination destination, {
    AuthNavigationMode mode = AuthNavigationMode.push,
  }) async {
    if (destination != AuthDestination.onboarding) {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(hasSeenOnboardingKey, true);
    }
    ref.read(authNavigationProvider.notifier).publish(destination, mode: mode);
  }

  void _selectPhoneChannel(PhoneVerificationChannel channel) {
    setState(() => _phoneChannel = channel);
  }

  void _openBillerCategory(String categoryKey) {
    setState(() => _selectedBillerCategory = categoryKey);
    _go(AppScreen.billerList);
  }

  void _removePinDigit() {
    if (_authPinCount == 0) return;
    setState(() => _authPinCount -= 1);
  }

  @override
  Widget build(BuildContext context) {
    final canExit =
        Navigator.of(context).canPop() ||
        _screen == AppScreen.bootstrap ||
        _screen == AppScreen.onboarding ||
        _screen == AppScreen.login ||
        (_screen == AppScreen.home && _history.isEmpty);
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _cancelFlowForScreen(_screen);
        } else {
          _back();
        }
      },
      child: _buildScreen(_screen),
    );
  }

  Widget _buildScreen(AppScreen screen) {
    switch (screen) {
      case AppScreen.bootstrap:
        return _bootstrapScreen();
      case AppScreen.onboarding:
        return _onboardingScreen();
      case AppScreen.verifyMethod:
        return _verifyMethodScreen();
      case AppScreen.otp:
        return _otpScreen();
      case AppScreen.createPassword:
        return _createPasswordScreen();
      case AppScreen.login:
        return _loginScreen();
      case AppScreen.passwordReset:
        return _passwordResetScreen();
      case AppScreen.newDeviceOtp:
        return _newDeviceOtpScreen();
      case AppScreen.createFirstPin:
        return _createFirstPinScreen();
      case AppScreen.tiers:
        return _tiersScreen();
      case AppScreen.tier1:
        return _tier1Screen();
      case AppScreen.tier2:
        return _tier2Screen();
      case AppScreen.nextOfKin:
        return _nextOfKinScreen();
      case AppScreen.tier3:
        return _tier3Screen();
      case AppScreen.home:
        return _homeScreen();
      case AppScreen.saveHub:
        return _saveHubScreen();
      case AppScreen.addMoney:
        return _addMoneyScreen();
      case AppScreen.sendHub:
        return _sendHubScreen();
      case AppScreen.sendOwn:
        return _sendOwnScreen();
      case AppScreen.sendBeneficiary:
        return _sendBeneficiaryScreen();
      case AppScreen.sendBank:
        return _sendBankScreen();
      case AppScreen.authPin:
        return _authPinScreen();
      case AppScreen.success:
        return _successScreen();
      case AppScreen.payments:
        return _paymentsScreen();
      case AppScreen.scan:
        return _scanScreen();
      case AppScreen.airtime:
        return _airtimeScreen();
      case AppScreen.data:
        return _dataScreen();
      case AppScreen.billerList:
        return _billerListScreen();
      case AppScreen.billPay:
        return _billPayScreen();
      case AppScreen.flex:
        return _flexScreen();
      case AppScreen.target:
        return _targetScreen();
      case AppScreen.lock:
        return _lockScreen();
      case AppScreen.group:
        return _groupScreen();
      case AppScreen.notifications:
        return _notificationsScreen();
      case AppScreen.loans:
        return _comingSoonScreen(
          title: 'Loans',
          icon: Icons.percent_rounded,
          message:
              "Loans aren't part of Cheetah's app yet — this release is focused on Savings and Payments. We'll let you know the moment borrowing is available.",
        );
      case AppScreen.cards:
        return _comingSoonScreen(
          title: 'Cards',
          icon: Icons.credit_card_rounded,
          message:
              "Virtual and physical debit cards aren't part of Cheetah's app yet. This release is focused on Savings and Payments previews. We'll let you know the moment cards are available.",
        );
      case AppScreen.routePreview:
        return _routePreviewScreen();
      case AppScreen.account:
        return _accountScreen();
    }
  }
}
