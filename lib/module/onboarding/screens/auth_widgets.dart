import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/app_router.dart';
import '../../../app/auth_navigation_provider.dart';
import '../../../app/preferences.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/auth_enums.dart';
import '../provider/security_action_providers.dart';

/// Publishes an auth destination. Leaving onboarding for any other auth
/// screen marks the intro as seen.
Future<void> openAuthDestination(
  WidgetRef ref,
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

/// Asks before signing out, then signs out.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
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
  if (confirmed == true && context.mounted) {
    await ref.read(logoutProvider.notifier).logout();
  }
}

/// Back for an auth screen, from the chevron or the system.
///
/// Pops when there is a route beneath. A screen entered with a cleared stack
/// has nothing to pop, so it returns to [fallback] instead; without one the
/// chevron is not shown at all rather than doing nothing.
class AuthBackScope extends ConsumerWidget {
  const AuthBackScope({
    required this.builder,
    this.fallback,
    this.exitsApp = false,
    this.onLeave,
    super.key,
  });

  /// Receives the chevron callback, or null when Back has nowhere to go.
  final Widget Function(BuildContext context, VoidCallback? onBack) builder;
  final AuthDestination? fallback;

  /// System Back may close the app from this screen.
  final bool exitsApp;

  /// Abandons this screen's in-flight flow when Back leaves it.
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigator = Navigator.of(context);
    void back() {
      onLeave?.call();
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }
      final destination = fallback;
      if (destination != null) {
        openAuthDestination(
          ref,
          destination,
          mode: AuthNavigationMode.clearStack,
        );
      }
    }

    final canPop = navigator.canPop();
    return PopScope(
      canPop: canPop || exitsApp,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          onLeave?.call();
        } else {
          back();
        }
      },
      child: builder(context, canPop || fallback != null ? back : null),
    );
  }
}

/// The shared sign-in and sign-up page: logo, heading, fields, and a primary
/// action that pins to the bottom when there is room.
class AuthPage extends StatelessWidget {
  const AuthPage({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.buttonLabel,
    required this.onButtonPressed,
    this.onBack,
    this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget content;
  final String buttonLabel;
  final VoidCallback onButtonPressed;
  final VoidCallback? onBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final onBack = this.onBack;
    final footer = this.footer;
    final fields = <Widget>[
      const BocLogo(height: 36),
      const SizedBox(height: 28),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontSize: 22),
      ),
      const SizedBox(height: 8),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          height: 1.55,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      const SizedBox(height: 28),
      content,
    ];
    final actions = Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(label: buttonLabel, onPressed: onButtonPressed),
          if (footer != null) ...[const SizedBox(height: 10), footer],
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        // Never render a chevron that cannot navigate: a screen entered with a
        // cleared stack has no history and nothing to pop.
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(IconsaxPlusLinear.arrow_left_1, size: 19),
                onPressed: onBack,
              ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContent(
          maxWidth: 560,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A pinned footer must not consume the form's viewport when a
              // keyboard or landscape window leaves little vertical space, so
              // the footer scrolls with the fields instead.
              //
              // Both cases must keep the SAME widget tree above the fields.
              // Returning two differently shaped trees re-parents every
              // TextFormField the instant the keyboard raises viewInsets. Its
              // FormFieldState is then rebuilt rather than reused, the focus
              // node it owns is disposed, and Flutter closes the input
              // connection — so the keyboard dismisses itself before a
              // character can be typed. Dismissing it drops viewInsets back to
              // zero, which restores the first shape, so it never settles.
              final tight =
                  constraints.maxHeight < 480 ||
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                      children: [
                        ...fields,
                        // Scrolls with the form only when space is tight.
                        if (tight) actions,
                      ],
                    ),
                  ),
                  // Pinned only when there is room for it.
                  if (!tight) actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Links to the legal documents customers should be able to review before
/// signing in or creating an account.
class AuthLegalNotice extends StatelessWidget {
  const AuthLegalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    final linkStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      textStyle: textStyle?.copyWith(fontWeight: FontWeight.w600),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: textStyle,
        ),
        const SizedBox(height: 2),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              style: linkStyle,
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.terms),
              child: const Text('Terms & Conditions'),
            ),
            Text('and', style: textStyle),
            TextButton(
              style: linkStyle,
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.privacyPolicy),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A flow's error or blocked message under its fields; nothing otherwise.
class AuthStateMessage extends StatelessWidget {
  const AuthStateMessage(this.state, {super.key});

  final NotifierState<Object?> state;

  @override
  Widget build(BuildContext context) {
    final message = state.message;
    if (message == null ||
        (!state.isError && state.status != ServiceStatus.blocked)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: BocColors.red, fontSize: 12),
      ),
    );
  }
}

class PhoneChannelSelector extends StatelessWidget {
  const PhoneChannelSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final PhoneVerificationChannel value;
  final ValueChanged<PhoneVerificationChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('SMS'),
            selected: value == PhoneVerificationChannel.sms,
            onSelected: (_) => onChanged(PhoneVerificationChannel.sms),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text('WhatsApp'),
            selected: value == PhoneVerificationChannel.whatsapp,
            onSelected: (_) => onChanged(PhoneVerificationChannel.whatsapp),
          ),
        ),
      ],
    );
  }
}
