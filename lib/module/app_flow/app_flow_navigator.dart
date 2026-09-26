import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../app/api_logger.dart';
import '../../app/app_router.dart';
import '../../app/auth_navigation_provider.dart';
import '../../app/bootstrap_provider.dart';
import '../../app/feature_capability.dart';
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
import '../account/model/withdrawal_bank_models.dart';
import '../account/provider/withdrawal_bank_providers.dart';
import '../home/model/user_home_model.dart';
import '../home/provider/home_provider.dart';
import '../savings/provider/savings_provider.dart';
import '../kyc/model/kyc_models.dart';
import '../kyc/model/kyc_provider_models.dart';
import '../kyc/model/kyc_status_models.dart';
import '../kyc/provider/kyc_providers.dart';
import '../kyc/provider/kyc_status_provider.dart';
import '../kyc/screens/smile_id_capture_screen.dart';
import '../kyc/screens/dojah_capture_screen.dart';
import '../kyc/service/dojah_config.dart';
import '../kyc/service/smile_id_gateway.dart';
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

part '../onboarding/screens/onboarding_flow_screens.dart';

part '../kyc/screens/kyc_screens.dart';

part '../home/screens/home_screen.dart';

part '../savings/screens/savings_screens.dart';
part '../savings/screens/savings_access_gate.dart';

part '../send/screens/send_screens.dart';

part '../payments/screens/payments_screens.dart';

part '../notifications/screens/notifications_screen.dart';

part '../account/screens/account_screens.dart';
part '../account/screens/linked_bank_accounts_screen.dart';

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
  /// Applies a KYC form-state change from the `KycScreens` extension.
  ///
  /// `setState` is protected, so an extension in another library calling it
  /// directly is `invalid_use_of_protected_member`. This is the sanctioned
  /// seam: the extension asks the State to rebuild, rather than reaching into
  /// a member it does not own.
  void refreshKycFormState(VoidCallback update) => setState(update);

  AppLifecycleListener? _lifecycleListener;

  late AppScreen _screen = widget.initialScreen;
  final List<AppScreen> _history = <AppScreen>[];
  int _onboardingIndex = 0;
  bool _verifyByPhone = true;
  PhoneVerificationChannel _phoneChannel = PhoneVerificationChannel.sms;

  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _currentSecretController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _identityNumberController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _governmentIdFormKey = GlobalKey<FormState>();
  GovernmentIdDocumentType _selectedDocumentType =
      GovernmentIdDocumentType.voterId;
  final _addressController = TextEditingController();
  final _addressStateController = TextEditingController();
  final _lgaController = TextEditingController();
  final _utilityProviderController = TextEditingController();
  final _utilityNumberController = TextEditingController();
  final _utilityBillFormKey = GlobalKey<FormState>();
  AutovalidateMode _utilityBillAutovalidate = AutovalidateMode.disabled;
  UtilityType? _selectedUtilityType;
  final _createPasswordFormKey = GlobalKey<FormState>();
  final _passwordResetFormKey = GlobalKey<FormState>();
  final _createFirstPinFormKey = GlobalKey<FormState>();
  final _identityFormKey = GlobalKey<FormState>();
  AutovalidateMode _createPasswordAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _passwordResetAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _createFirstPinAutovalidate = AutovalidateMode.disabled;
  AutovalidateMode _identityAutovalidate = AutovalidateMode.disabled;
  IdentityType _selectedIdentityType = IdentityType.bvn;

  @override
  void initState() {
    super.initState();
    // `/account/tier/nin` preselects NIN; every other entry point defaults to
    // BVN. Set once here so the user's own dropdown choice always wins after.
    if (widget.initialRouteName == AppRoutes.tier2Nin) {
      _selectedIdentityType = IdentityType.nin;
    }
    // A KYC verdict arrives by webhook while the app is backgrounded, so the
    // authoritative state is re-read on resume. KycAuthoritativeRefresh shares
    // one in-flight round with the manual Refresh and the post-submission
    // refresh, so no extra debounce belongs here.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted || !_isKycScreen(_screen)) return;
        ref.read(kycAuthoritativeRefreshProvider)();
      },
    );

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
    _identityNumberController.dispose();
    _documentNumberController.dispose();
    _addressController.dispose();
    _addressStateController.dispose();
    _lgaController.dispose();
    _utilityProviderController.dispose();
    _utilityNumberController.dispose();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  static bool _isKycScreen(AppScreen screen) =>
      screen == AppScreen.kycIdentity ||
      screen == AppScreen.kycGovernmentId ||
      screen == AppScreen.kycUtilityBill ||
      screen == AppScreen.tiers;

  void _go(AppScreen next, {bool replace = false}) {
    if (_screen == AppScreen.kycIdentity && next != AppScreen.kycIdentity) {
      ref.read(identityVerificationProvider.notifier).cancelPendingRequest();
    }
    setState(() {
      if (!replace) _history.add(_screen);
      _screen = next;
      _savingsLoadedFor = null;
      _savingsAuthorizedFor = null;
    });
  }

  /// Whether [_back] has anywhere to go from the current screen.
  ///
  /// A screen entered with [AuthNavigationMode.clearStack] has no in-app
  /// history and no route beneath it, so a back control there is inert. Asking
  /// this before rendering one keeps the chevron honest instead of showing a
  /// button that silently does nothing.
  bool get _canGoBack =>
      _history.isNotEmpty ||
      Navigator.of(context).canPop() ||
      _authFallbackFor(_screen) != null;

  /// Where an auth screen returns to when it has no history to pop.
  ///
  /// "Create an account" reaches the verification flow with `clearStack`, which
  /// wipes the route beneath it. Without an explicit destination the user is
  /// stranded with no way back to Login.
  AuthDestination? _authFallbackFor(AppScreen screen) => switch (screen) {
    AppScreen.verifyMethod || AppScreen.passwordReset => AuthDestination.login,
    AppScreen.otp ||
    AppScreen.createPassword => AuthDestination.verificationMethod,
    _ => null,
  };

  void _back() {
    // System Back also reaches this callback while the access gate is loading.
    // It must not fall through to an ungated Home before PIN status is known.
    if (_isSavingsDestination && !_hasSavingsAccess) return;
    _cancelFlowForScreen(_screen);
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

    // Nothing to pop: this screen was entered with a cleared stack. Route to
    // its declared origin rather than doing nothing.
    final fallback = _authFallbackFor(_screen);
    if (fallback != null) {
      _openAuthDestination(fallback, mode: AuthNavigationMode.clearStack);
    } else if (_isSavingsDestination) {
      _go(
        _screen == AppScreen.saveHub ? AppScreen.home : AppScreen.saveHub,
        replace: true,
      );
    }
  }

  /// Returns to the tier list once a KYC step has been submitted.
  ///
  /// The step screens are opened from that list, so it is where the user
  /// expects to land, and the card their submission changes lives there. The
  /// path taken to the step is dropped so Back does not lead to a form that
  /// has already been sent. When the list is not in this navigator's history
  /// — the step was deep-linked, as `/account/tier/bvn` is — the step screen
  /// is replaced by it instead.
  void _returnToTierList() {
    final index = _history.lastIndexOf(AppScreen.tiers);
    if (index >= 0) _history.removeRange(index, _history.length);
    _go(AppScreen.tiers, replace: true);
  }

  void _cancelFlowForScreen(AppScreen screen) {
    if (screen == AppScreen.kycIdentity) {
      ref.read(identityVerificationProvider.notifier).cancelPendingRequest();
    }
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

  @override
  Widget build(BuildContext context) {
    if (_isSavingsDestination) {
      // Keep the native Back policy reactive even on static unavailable pages.
      ref.watch(authSessionProvider);
      ref.watch(userProfileProvider);
    }
    final canExit =
        Navigator.of(context).canPop() ||
        _screen == AppScreen.bootstrap ||
        _screen == AppScreen.onboarding ||
        _screen == AppScreen.login ||
        (_screen == AppScreen.home && _history.isEmpty);
    return PopScope(
      canPop: canExit && (!_isSavingsDestination || _hasSavingsAccess),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _cancelFlowForScreen(_screen);
        } else {
          _back();
        }
      },
      child: _isSavingsDestination
          ? SavingsAccessGate(
              onSignedOut: () => _redirectSavingsAuth(AppRoutes.login),
              onCreatePin: () => _redirectSavingsAuth(AppRoutes.createFirstPin),
              builder: (_) {
                _savingsAuthorizedFor = ref
                    .read(authSessionProvider)
                    ?.accessToken;
                _ensureSavingsLoaded();
                return _buildScreen(_screen);
              },
            )
          : _buildScreen(_screen),
    );
  }

  String? _savingsLoadedFor;
  String? _savingsAuthorizedFor;

  void _redirectSavingsAuth(String route) {
    // Do not leave a private route beneath login/PIN setup in either stack.
    _history.clear();
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  bool get _hasSavingsAccess {
    final session = ref.read(authSessionProvider);
    final profile = ref.read(userProfileProvider).data;
    return session != null &&
        !session.isExpired &&
        _savingsAuthorizedFor == session.accessToken &&
        profile?.userId == session.userId &&
        profile?.isCreatedPin == true;
  }

  bool get _isSavingsDestination => switch (_screen) {
    AppScreen.saveHub ||
    AppScreen.flex ||
    AppScreen.target ||
    AppScreen.lock ||
    AppScreen.group ||
    AppScreen.addMoney => true,
    AppScreen.routePreview =>
      widget.initialRouteName?.startsWith('/savings/') == true ||
          widget.initialRouteName == AppRoutes.bankTransferFunding ||
          widget.initialRouteName == AppRoutes.cardFunding,
    _ => false,
  };

  void _ensureSavingsLoaded() {
    final session = ref.read(authSessionProvider);
    if (session == null ||
        session.isExpired ||
        _savingsLoadedFor == session.accessToken) {
      return;
    }
    _savingsLoadedFor = session.accessToken;
    final funding =
        _screen == AppScreen.addMoney ||
        (_screen == AppScreen.routePreview &&
            (widget.initialRouteName == AppRoutes.flexTopUp ||
                widget.initialRouteName == AppRoutes.bankTransferFunding));
    final needsData =
        funding || _screen == AppScreen.saveHub || _screen == AppScreen.flex;
    if (needsData &&
        (funding || ref.read(userHomeProvider).status == ServiceStatus.idle)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(authSessionProvider)?.accessToken == session.accessToken) {
          unawaited(ref.read(userHomeProvider.notifier).load());
        }
      });
    }
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
      case AppScreen.kycIdentity:
        return _kycIdentityScreen();
      case AppScreen.kycGovernmentId:
        return _kycGovernmentIdScreen();
      case AppScreen.nextOfKin:
        return _nextOfKinScreen();
      case AppScreen.kycUtilityBill:
        return _kycUtilityBillScreen();
      case AppScreen.linkedBanks:
        return _linkedBankAccountsScreen();
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
          capability: FeatureCapability.loans,
          title: 'Loans',
          icon: Icons.percent_rounded,
          message:
              "Loans aren't part of Cheetah's app yet — this release is focused on Savings.",
        );
      case AppScreen.cards:
        return _comingSoonScreen(
          capability: FeatureCapability.cards,
          title: 'Cards',
          icon: Icons.credit_card_rounded,
          message:
              "Virtual and physical debit cards aren't part of Cheetah's app yet. This release is focused on Savings.",
        );
      case AppScreen.routePreview:
        return _routePreviewScreen();
      case AppScreen.account:
        return _accountScreen();
    }
  }
}
