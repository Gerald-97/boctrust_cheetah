import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/response_handler.dart';
import '../../../app/theme.dart';
import '../../../utils/auth_input.dart';
import '../../../utils/validators.dart' as validators;
import '../../app_flow/app_ui.dart';
import '../../component/text_fields.dart';
import '../../kyc/model/kyc_contact_requirement.dart';
import '../../onboarding/model/auth_enums.dart';
import '../../onboarding/model/auth_flow_models.dart';
import '../../onboarding/provider/identifier_verification_provider.dart';
import '../../onboarding/provider/test_otp_provider.dart';
import '../model/user_profile_model.dart';
import '../provider/user_providers.dart';

/// Email and phone verification for any screen that needs them, most often
/// before KYC.
extension ContactVerification on ConsumerState {
  /// Verifies the customer's phone ([phone]) or email with a one-time code.
  /// Pops with true once the backend confirms the code.
  Future<bool> showContactVerificationSheet({
    required bool phone,
    String? initialValue,
    String? reason,
  }) async {
    if (!mounted) return false;
    ref.invalidate(identifierVerificationProvider);
    var channel = PhoneVerificationChannel.sms;
    var keepOtpStepVisible = false;
    // When the last code was sent; Resend unlocks after a short cooldown even
    // if the code itself is still valid, so a lost code is not a long wait.
    DateTime? codeSentAt;
    const resendCooldown = Duration(seconds: 60);
    // Rebuilds the sheet each second while a cooldown is counting down.
    Timer? ticker;

    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _SheetControllers(
        initialIdentifier: initialValue ?? '',
        builder: (identifierController, otpController) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Consumer(
            builder: (context, modalRef, _) {
              final state = modalRef.watch(identifierVerificationProvider);
              final awaitingOtp =
                  state.data?.stage == IdentifierVerificationStage.awaitingOtp;
              final showingOtp = awaitingOtp || keepOtpStepVisible;
              final expiresAt = state.data?.otpExpiresAt;
              final now = DateTime.now().toUtc();
              final cooldownLeft = codeSentAt == null
                  ? Duration.zero
                  : resendCooldown - now.difference(codeSentAt!);
              final expired =
                  expiresAt == null || !now.isBefore(expiresAt.toUtc());
              final canResend =
                  showingOtp &&
                  !state.isLoading &&
                  (expired || cooldownLeft <= Duration.zero);
              if (showingOtp && cooldownLeft > Duration.zero) {
                ticker ??= Timer.periodic(const Duration(seconds: 1), (timer) {
                  if (!sheetContext.mounted) return timer.cancel();
                  setSheetState(() {});
                });
              } else {
                ticker?.cancel();
                ticker = null;
              }

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  24,
                  22,
                  24,
                  22 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        showingOtp
                            ? 'Enter verification code'
                            : phone
                            ? 'Verify phone number'
                            : 'Verify email address',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (!showingOtp && reason != null) ...[
                        Text(
                          reason,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        showingOtp
                            ? 'Enter the 6-digit code sent to ${state.data?.identifier}.'
                            : 'BOCTRUST will send a one-time verification code.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      if (showingOtp) ...[
                        PinInputField(
                          pinCtrl: otpController,
                          isActive: awaitingOtp && !state.isLoading,
                        ),
                        const SizedBox(height: 10),
                        OtpExpiryLabel(
                          expiresAt: expiresAt,
                          onExpired: () {
                            if (sheetContext.mounted) setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                        TestOtpBanner(
                          flow: TestOtpFlow.identifierVerification,
                          controller: otpController,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: canResend
                                  ? () async {
                                      final data = state.data;
                                      if (data == null ||
                                          data.identifier.trim().isEmpty) {
                                        return;
                                      }
                                      setSheetState(
                                        () => keepOtpStepVisible = true,
                                      );
                                      otpController.clear();
                                      final notifier = modalRef.read(
                                        identifierVerificationProvider.notifier,
                                      );
                                      if (phone) {
                                        await notifier.initiatePhone(
                                          data.identifier,
                                          data.phoneVerificationChannel ??
                                              channel,
                                        );
                                      } else {
                                        await notifier.initiateEmail(
                                          data.identifier,
                                        );
                                      }
                                      if (!sheetContext.mounted) return;
                                      final resent = modalRef.read(
                                        identifierVerificationProvider,
                                      );
                                      setSheetState(() {
                                        if (resent.data?.stage ==
                                            IdentifierVerificationStage
                                                .awaitingOtp) {
                                          codeSentAt = DateTime.now().toUtc();
                                        } else {
                                          // A failed resend has no code to
                                          // verify: return to the field,
                                          // which keeps the error message.
                                          keepOtpStepVisible = false;
                                        }
                                      });
                                    }
                                  : null,
                              child: Text(
                                canResend || expired
                                    ? 'Resend code'
                                    : 'Resend code in '
                                          '${cooldownLeft.inSeconds + 1}s',
                              ),
                            ),
                            TextButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () {
                                      modalRef.invalidate(
                                        identifierVerificationProvider,
                                      );
                                      otpController.clear();
                                      setSheetState(() {
                                        keepOtpStepVisible = false;
                                        codeSentAt = null;
                                      });
                                    },
                              child: Text(
                                phone ? 'Change number' : 'Change email',
                              ),
                            ),
                          ],
                        ),
                      ] else if (!phone) ...[
                        AppTextField(
                          label: 'Email address',
                          controller: identifierController,
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ] else ...[
                        AppTextField(
                          label: 'Phone number',
                          hintText: '0801 234 5678',
                          controller: identifierController,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<PhoneVerificationChannel>(
                          segments: const [
                            ButtonSegment(
                              value: PhoneVerificationChannel.sms,
                              label: Text('SMS'),
                            ),
                            ButtonSegment(
                              value: PhoneVerificationChannel.whatsapp,
                              label: Text('WhatsApp'),
                            ),
                          ],
                          selected: {channel},
                          onSelectionChanged: state.isLoading
                              ? null
                              : (selection) {
                                  setSheetState(
                                    () => channel = selection.single,
                                  );
                                },
                        ),
                      ],
                      if (state.isError) ...[
                        const SizedBox(height: 12),
                        Text(
                          state.message ?? 'Verification failed.',
                          style: const TextStyle(color: BocColors.red),
                        ),
                      ],
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: state.isLoading
                            ? 'Please wait…'
                            : showingOtp
                            ? 'Verify code'
                            : 'Send code',
                        onPressed:
                            state.isLoading || (showingOtp && !awaitingOtp)
                            ? null
                            : () async {
                                final notifier = modalRef.read(
                                  identifierVerificationProvider.notifier,
                                );
                                if (showingOtp) {
                                  if (validators.otp(otpController.text) !=
                                      null) {
                                    ResponseHandler.showInfo(
                                      'Enter the 6-digit code.',
                                    );
                                    return;
                                  }
                                  await notifier.verify(otpController.text);
                                  final result = modalRef.read(
                                    identifierVerificationProvider,
                                  );
                                  if (result.data?.stage ==
                                          IdentifierVerificationStage
                                              .completed &&
                                      sheetContext.mounted) {
                                    Navigator.pop(sheetContext, true);
                                  }
                                  return;
                                }

                                final identifier = identifierController.text
                                    .trim();
                                if (phone) {
                                  if (!isValidNigerianPhone(identifier)) {
                                    ResponseHandler.showInfo(
                                      'Enter a valid Nigerian phone number.',
                                    );
                                    return;
                                  }
                                  await notifier.initiatePhone(
                                    identifier,
                                    channel,
                                  );
                                } else {
                                  if (!validators.isEmail(identifier)) {
                                    ResponseHandler.showInfo(
                                      'Enter a valid email address.',
                                    );
                                    return;
                                  }
                                  await notifier.initiateEmail(identifier);
                                }
                                if (modalRef
                                            .read(
                                              identifierVerificationProvider,
                                            )
                                            .data
                                            ?.stage ==
                                        IdentifierVerificationStage
                                            .awaitingOtp &&
                                    sheetContext.mounted) {
                                  setSheetState(
                                    () => codeSentAt = DateTime.now().toUtc(),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    ticker?.cancel();
    if (!mounted) return false;
    ref.invalidate(identifierVerificationProvider);
    if (verified == true) {
      ResponseHandler.showSuccess(
        phone ? 'Phone number verified.' : 'Email address verified.',
      );
    }
    return verified ?? false;
  }

  /// Makes sure the customer's email and phone are verified before KYC.
  ///
  /// Opens a verification sheet for each missing detail, email first, and
  /// reloads the profile after each. Returns whether both are now verified.
  Future<bool> ensureContactsForKyc() async {
    final profileNotifier = ref.read(userProfileProvider.notifier);
    var profileState = ref.read(userProfileProvider);
    if (profileState.data == null) profileState = await profileNotifier.load();
    if (!mounted) return false;
    if (profileState.isError || profileState.data == null) {
      ResponseHandler.showError(
        profileState.message ?? 'We could not load your profile. Please retry.',
      );
      return false;
    }

    for (final phone in [false, true]) {
      final ready = phone ? isPhoneReadyForKyc : isEmailReadyForKyc;
      if (ready(profileState.data)) continue;
      final profile = profileState.data;
      final verified = await showContactVerificationSheet(
        phone: phone,
        initialValue: phone ? profile?.phoneNumber : profile?.email,
        reason: phone
            ? 'We need your phone number to verify your identity.'
            : 'We need your email address to verify your identity.',
      );
      if (!verified) return false;

      profileState = await profileNotifier.load();
      if (!mounted) return false;
      if (profileState.isError || !ready(profileState.data)) {
        ResponseHandler.showError(
          profileState.message ??
              'Your ${phone ? 'phone number' : 'email address'} was '
                  'verified, but your profile could not be refreshed.',
        );
        return false;
      }
    }
    return true;
  }

  /// The prompt shown wherever KYC waits on the email or phone. [onVerified]
  /// runs once both are verified.
  Widget contactRequirementCard(
    UserOwnProfileData profile, {
    VoidCallback? onVerified,
  }) => ApiStateCard(
    title: 'Verify your ${missingKycContacts(profile)}',
    message:
        "You'll need them to verify your identity and unlock higher limits.",
    tone: ApiStateTone.info,
    actionLabel: 'Continue',
    onAction: () async {
      if (await ensureContactsForKyc() && mounted) onVerified?.call();
    },
  );
}

/// Owns the sheet's text controllers for exactly as long as the sheet is in
/// the tree, closing animation included.
class _SheetControllers extends StatefulWidget {
  const _SheetControllers({
    required this.initialIdentifier,
    required this.builder,
  });

  final String initialIdentifier;
  final Widget Function(
    TextEditingController identifier,
    TextEditingController otp,
  )
  builder;

  @override
  State<_SheetControllers> createState() => _SheetControllersState();
}

class _SheetControllersState extends State<_SheetControllers> {
  late final _identifier = TextEditingController(
    text: widget.initialIdentifier,
  );
  final _otp = TextEditingController();

  @override
  void dispose() {
    _identifier.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_identifier, _otp);
}
