import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/bootstrap_provider.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/auth_flow_models.dart';
import 'auth_widgets.dart';
import 'onboarding_slide_view.dart';
import 'startup_brand_sequence.dart';

/// Restores the session and loads the profile before routing onwards.
class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupGateProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (state.status == ServiceStatus.idle) {
      final gate = ref.read(startupGateProvider.notifier);
      Future<void>.microtask(
        reduceMotion
            ? () => gate.start(minimumSplashDuration: Duration.zero)
            : gate.start,
      );
    }
    final showsSplash = switch (state.data?.stage) {
      StartupGateStage.idle || StartupGateStage.clearingSession => true,
      // A cold launch keeps its final frame while the route changes. The
      // post-login load never routes to login or onboarding.
      StartupGateStage.complete => const {
        AuthDestination.login,
        AuthDestination.onboarding,
      }.contains(state.data?.destination),
      _ => false,
    };
    if (showsSplash) {
      return AuthBackScope(
        exitsApp: true,
        builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: BocColors.goldLight,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: BocColors.goldLight,
            body: StartupBrandSequence(reduceMotion: reduceMotion),
          ),
        ),
      );
    }
    final hasError = state.status == ServiceStatus.error;
    return AuthBackScope(
      exitsApp: true,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ResponsiveContent(
            maxWidth: 560,
            child: ScrollableFill(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CheetahBrand.launch(),
                      const SizedBox(height: 28),
                      if (!hasError) ...[
                        const CircularProgressIndicator(),
                        const SizedBox(height: 18),
                        Text(
                          state.data?.stage == StartupGateStage.loadingProfile
                              ? 'Loading your account…'
                              : 'Starting securely…',
                        ),
                      ] else ...[
                        const Icon(
                          IconsaxPlusLinear.cloud_cross,
                          size: 48,
                          color: BocColors.gold,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          state.message ?? 'Unable to load your account.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: 'Retry',
                          onPressed: () => ref
                              .read(startupGateProvider.notifier)
                              .retryProfile(),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => confirmSignOut(context, ref),
                          child: const Text('Sign out'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The three intro slides shown before sign-up or sign-in.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _slides = <({String art, String title, String description})>[
    (
      art: 'save',
      title: 'Save without thinking about it',
      description:
          'Boc Flex Savings grows every day with no lock-in. SmartSave, Fixed Deposit and Padi help you commit to a goal, on your terms.',
    ),
    (
      art: 'goals',
      title: 'Reach any goal, your way',
      description:
          'Save toward a goal, lock in a fixed term for a higher rate, or save together with friends — pick whichever fits.',
    ),
    (
      art: 'pay',
      title: 'Send and pay, instantly',
      description:
          'Move money between your BOCTRUST accounts, send to friends and family, or pay bills — all in one place.',
    ),
  ];

  int _index = 0;

  void _advance() {
    if (_index < _slides.length - 1) {
      setState(() => _index += 1);
      return;
    }
    openAuthDestination(ref, AuthDestination.verificationMethod);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return AuthBackScope(
      exitsApp: true,
      builder: (context, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: BocColors.card,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: BocColors.paper,
          body: OnboardingSlideView(
            gifAsset: 'assets/img/onboarding/${slide.art}.gif',
            stillAsset: 'assets/img/onboarding/${slide.art}-still.png',
            title: slide.title,
            description: slide.description,
            index: _index,
            slideCount: _slides.length,
            onNext: _advance,
            onSelect: (index) => setState(() => _index = index),
            onLogin: () => openAuthDestination(
              ref,
              AuthDestination.login,
              mode: AuthNavigationMode.clearStack,
            ),
          ),
        ),
      ),
    );
  }
}
