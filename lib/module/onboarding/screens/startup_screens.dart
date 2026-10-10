import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../../app/auth_navigation_provider.dart';
import '../../../app/boc_icons.dart';
import '../../../app/bootstrap_provider.dart';
import '../../../app/services.dart';
import '../../../app/theme.dart';
import '../../app_flow/app_ui.dart';
import '../model/auth_flow_models.dart';
import 'auth_widgets.dart';

/// Restores the session and loads the profile before routing onwards.
class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(startupGateProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(startupGateProvider.notifier).start);
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
  static const _slides = <({IconData icon, String title, String description})>[
    (
      icon: BocIcons.savings,
      title: 'Save without thinking about it',
      description:
          'Boc Flex Savings grows every day with no lock-in. SmartSave, Fixed Deposit and Padi help you commit to a goal, on your terms.',
    ),
    (
      icon: IconsaxPlusLinear.flag,
      title: 'Reach any goal, your way',
      description:
          'Save toward a goal, lock in a fixed term for a higher rate, or save together with friends — pick whichever fits.',
    ),
    (
      icon: IconsaxPlusLinear.send_2,
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
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: ResponsiveContent(
            maxWidth: 560,
            child: ScrollableFill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => openAuthDestination(
                          ref,
                          AuthDestination.verificationMethod,
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const CheetahBrand.launch(markSize: 52),
                    const Spacer(),
                    OnboardingIllustration(icon: slide.icon),
                    const SizedBox(height: 30),
                    Text(
                      slide.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall?.copyWith(fontSize: 23),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (index) => GestureDetector(
                          onTap: () => setState(() => _index = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _index ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index == _index
                                  ? BocColors.gold
                                  : Theme.of(context).dividerColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 5),
                    const RegulatoryBadge(),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      label: _index == _slides.length - 1
                          ? 'Get started'
                          : 'Next',
                      onPressed: _advance,
                    ),
                    TextButton(
                      onPressed: () => openAuthDestination(
                        ref,
                        AuthDestination.login,
                        mode: AuthNavigationMode.clearStack,
                      ),
                      child: const Text('I already have an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
