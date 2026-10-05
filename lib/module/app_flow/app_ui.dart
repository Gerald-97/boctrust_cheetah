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
import '../../app/feature_capability.dart';
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../account/provider/user_providers.dart';
import '../send/model/transaction_models.dart';
import '../kyc/screens/kyc_screens.dart';
import '../home/screens/home_screen.dart';
import '../account/screens/account_screens.dart';
import '../core_banking/screens/beneficiaries_screen.dart';
import '../notifications/screens/notifications_screen.dart';
import 'flow_page.dart';
import '../payments/screens/payments_screens.dart';
import '../send/screens/send_screens.dart';
import '../savings/screens/savings_screens.dart';
import '../onboarding/screens/login_screens.dart';
import '../onboarding/screens/recovery_screens.dart';
import '../onboarding/screens/signup_screens.dart';
import '../onboarding/screens/startup_screens.dart';
import '../onboarding/provider/auth_session_provider.dart';
import '../onboarding/provider/test_otp_provider.dart';

part 'route_definitions.dart';
part 'section_shell.dart';

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
