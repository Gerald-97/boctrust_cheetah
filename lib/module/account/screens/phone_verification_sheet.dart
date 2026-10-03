part of '../../app_flow/app_flow_navigator.dart';

extension PhoneVerificationSheet on AppFlowNavigatorState {
  Future<bool> _showPhoneVerificationSheet({
    String? initialPhone,
    String? reason,
  }) async {
    if (!mounted) return false;
    ref.invalidate(identifierVerificationProvider);
    _identifierController.text = initialPhone ?? '';
    _otpController.clear();
    var channel = PhoneVerificationChannel.sms;
    var keepOtpStepVisible = false;
    // When the last code was sent; Resend unlocks after a short cooldown even
    // if the code itself is still valid, so a lost SMS is not a long wait.
    DateTime? codeSentAt;
    const resendCooldown = Duration(seconds: 60);
    // Rebuilds the sheet each second while a cooldown is counting down.
    Timer? ticker;

    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
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
                          : 'Verify phone number',
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
                        pinCtrl: _otpController,
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
                        controller: _otpController,
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
                                    _otpController.clear();
                                    final notifier = modalRef.read(
                                      identifierVerificationProvider.notifier,
                                    );
                                    await notifier.initiatePhone(
                                      data.identifier,
                                      data.phoneVerificationChannel ?? channel,
                                    );
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
                                        // verify: return to the number,
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
                                    _otpController.clear();
                                    setSheetState(() {
                                      keepOtpStepVisible = false;
                                      codeSentAt = null;
                                    });
                                  },
                            child: const Text('Change number'),
                          ),
                        ],
                      ),
                    ] else ...[
                      AppTextField(
                        label: 'Phone number',
                        hintText: '0801 234 5678',
                        controller: _identifierController,
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
                                setSheetState(() => channel = selection.single);
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
                      onPressed: state.isLoading || (showingOtp && !awaitingOtp)
                          ? null
                          : () async {
                              final notifier = modalRef.read(
                                identifierVerificationProvider.notifier,
                              );
                              if (showingOtp) {
                                if (validators.otp(_otpController.text) !=
                                    null) {
                                  _showMessage('Enter the 6-digit code.');
                                  return;
                                }
                                await notifier.verify(_otpController.text);
                                final result = modalRef.read(
                                  identifierVerificationProvider,
                                );
                                if (result.data?.stage ==
                                        IdentifierVerificationStage.completed &&
                                    sheetContext.mounted) {
                                  Navigator.pop(sheetContext, true);
                                }
                                return;
                              }

                              final identifier = _identifierController.text
                                  .trim();
                              if (!isValidNigerianPhone(identifier)) {
                                _showMessage(
                                  'Enter a valid Nigerian phone number.',
                                );
                                return;
                              }
                              await notifier.initiatePhone(identifier, channel);
                              if (modalRef
                                          .read(identifierVerificationProvider)
                                          .data
                                          ?.stage ==
                                      IdentifierVerificationStage.awaitingOtp &&
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
    );

    ticker?.cancel();
    if (!mounted) return false;
    _identifierController.clear();
    _otpController.clear();
    ref.invalidate(identifierVerificationProvider);
    if (verified == true) {
      _showSuccessMessage('Phone number verified.');
    }
    return verified ?? false;
  }

  Future<bool> _ensurePhoneForKyc() async {
    final profileNotifier = ref.read(userProfileProvider.notifier);
    var profileState = ref.read(userProfileProvider);
    if (profileState.data == null) profileState = await profileNotifier.load();
    if (!mounted) return false;
    if (profileState.isError || profileState.data == null) {
      _showErrorMessage(
        profileState.message ?? 'We could not load your profile. Please retry.',
      );
      return false;
    }
    if (isPhoneReadyForKyc(profileState.data)) return true;

    final verified = await _showPhoneVerificationSheet(
      initialPhone: profileState.data?.phoneNumber,
      reason: 'We need your phone number to verify your identity.',
    );
    if (!verified) return false;

    final refreshed = await profileNotifier.load();
    if (!mounted) return false;
    if (refreshed.isError || !isPhoneReadyForKyc(refreshed.data)) {
      _showErrorMessage(
        refreshed.message ??
            'Your phone was verified, but your profile could not be refreshed.',
      );
      return false;
    }
    return true;
  }
}
