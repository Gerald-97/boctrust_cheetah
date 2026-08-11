import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';

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

part '../onboarding/screens/onboarding_flow_screens.dart';

part '../account/screens/kyc_screens.dart';

part '../home/screens/home_screen.dart';

part '../savings/screens/savings_screens.dart';

part '../send/screens/send_screens.dart';

part '../payments/screens/payments_screens.dart';

part '../notifications/screens/notifications_screen.dart';

part '../account/screens/account_screens.dart';

class AppFlowRouteScreen extends StatelessWidget {
  const AppFlowRouteScreen({super.key, required this.initialScreen});

  final AppScreen initialScreen;

  @override
  Widget build(BuildContext context) {
    return AppFlowNavigator(initialScreen: initialScreen);
  }
}

class AppFlowNavigator extends ConsumerStatefulWidget {
  const AppFlowNavigator({
    this.initialScreen = AppScreen.onboarding,
    super.key,
  });

  final AppScreen initialScreen;

  @override
  ConsumerState<AppFlowNavigator> createState() => AppFlowNavigatorState();
}

class AppFlowNavigatorState extends ConsumerState<AppFlowNavigator> {
  late AppScreen _screen = widget.initialScreen;
  final List<AppScreen> _history = <AppScreen>[];
  int _onboardingIndex = 0;
  bool _verifyByPhone = true;
  bool _balanceHidden = false;
  int _authPinCount = 0;
  String _selectedBillerCategory = 'electricity';
  BillerItem _selectedBiller = const BillerItem(
    'Eko Electricity Distribution Co. (EKEDC)',
    'Lagos — Eko & environs',
  );
  TransactionContext _transaction = const TransactionContext(
    amount: '₦35,000.00',
    description: 'Sent to Ifeoma Nwachukwu · BOCTrust.',
    title: 'Transfer successful',
    row1Label: 'Recipient',
    row1Value: 'Ifeoma Nwachukwu',
    row2Label: 'Account',
    row2Value: '0198 220 341',
  );

  void _go(AppScreen next, {bool replace = false}) {
    setState(() {
      if (!replace) _history.add(_screen);
      _screen = next;
      if (next == AppScreen.authPin) _authPinCount = 0;
    });
  }

  void _back() {
    setState(() {
      if (_history.isNotEmpty) {
        _screen = _history.removeLast();
      } else {
        _screen = AppScreen.home;
      }
    });
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  void _toggleBalanceHidden() {
    setState(() => _balanceHidden = !_balanceHidden);
  }

  void _selectOnboardingIndex(int index) {
    setState(() => _onboardingIndex = index);
  }

  void _advanceOnboarding() {
    if (_onboardingIndex < 2) {
      setState(() => _onboardingIndex += 1);
      return;
    }
    _go(AppScreen.verifyMethod);
  }

  void _selectVerificationMethod({required bool phone}) {
    setState(() => _verifyByPhone = phone);
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
        _screen == AppScreen.onboarding ||
        (_screen == AppScreen.home && _history.isEmpty);
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: _buildScreen(_screen),
    );
  }

  Widget _buildScreen(AppScreen screen) {
    switch (screen) {
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
      case AppScreen.tiers:
        return _tiersScreen();
      case AppScreen.tier1:
        return _tier1Screen();
      case AppScreen.tier2:
        return _tier2Screen();
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
              "Loans aren't part of BOCTrust's app yet — this release is focused on Savings and Payments. We'll let you know the moment borrowing is available.",
        );
      case AppScreen.cards:
        return _comingSoonScreen(
          title: 'Cards',
          icon: Icons.credit_card_rounded,
          message:
              "Virtual and physical debit cards aren't part of BOCTrust's app yet — this release is focused on Savings and Payments. We'll let you know the moment cards are available.",
        );
      case AppScreen.account:
        return _accountScreen();
    }
  }
}
