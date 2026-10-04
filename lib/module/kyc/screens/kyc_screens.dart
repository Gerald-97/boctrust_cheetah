part of '../../app_flow/app_flow_navigator.dart';

extension KycScreens on AppFlowNavigatorState {
  /// Watches the authoritative status, loading it the first time a KYC screen
  /// opens.
  ///
  /// The backend is the only source that may show verification; local flow
  /// stages describe what this process has attempted, nothing more.
  NotifierState<KycStatusData> _watchKycStatus() {
    final state = ref.watch(kycStatusProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(kycStatusProvider.notifier).load);
    }
    return state;
  }

  /// What a KYC form shows instead of itself until the email and phone are
  /// verified, or null once they are.
  Widget? _kycContactGate() {
    final profileState = ref.watch(userProfileProvider);
    if (profileState.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    final profile = profileState.data;
    if (areContactsReadyForKyc(profile)) return null;
    if (profile != null) return _contactRequirementCard(profile);
    return profileState.isError
        ? ApiStateCard(
            title: 'Profile unavailable',
            message: profileState.message ?? 'We could not load your profile.',
            tone: ApiStateTone.error,
            actionLabel: 'Retry',
            onAction: () => ref.read(userProfileProvider.notifier).load(),
          )
        : const ApiLoadingSection(label: 'Loading your profile');
  }

  /// A KYC start the backend refused because no verified email or phone is
  /// on file. Narrow this to the exact codes once the backend publishes them
  /// (gate P1).
  bool _isContactRequiredError(NotifierState<Object?> state) {
    final code = (state.errorCode ?? '').toUpperCase();
    return (code.contains('PHONE') || code.contains('EMAIL')) &&
        RegExp('REQUIRED|NOT_VERIFIED|UNVERIFIED|MISSING').hasMatch(code);
  }

  /// Re-reads the profile: a stale one opens the verification sheets,
  /// otherwise the backend's own message is shown.
  Future<void> _handleContactRequiredError(
    NotifierState<Object?> result,
  ) async {
    final profileState = await ref.read(userProfileProvider.notifier).load();
    if (!mounted) return;
    if (areContactsReadyForKyc(profileState.data)) {
      _showErrorMessage(
        result.message ?? 'Verification could not start. Please try again.',
      );
    } else {
      await _ensureContactsForKyc();
    }
  }

  String _statusLabel(KycVerificationStatus status) => switch (status) {
    KycVerificationStatus.success => 'Verified',
    KycVerificationStatus.pending => 'Pending',
    KycVerificationStatus.failed => 'Failed',
    KycVerificationStatus.notStarted => 'Not started',
    // An unrecognized status is never presented as progress.
    KycVerificationStatus.unknown => 'Not started',
  };

  Color _statusColor(KycVerificationStatus status) => switch (status) {
    KycVerificationStatus.success => BocColors.green,
    KycVerificationStatus.pending => BocColors.gold,
    KycVerificationStatus.failed => BocColors.red,
    KycVerificationStatus.notStarted ||
    KycVerificationStatus.unknown => BocColors.grey,
  };

  /// What the backend says to do next, or null when there is nothing to say.
  ///
  /// An unrecognized action returns null rather than inventing guidance, and
  /// never reads as a finished journey.
  String? _nextActionMessage(KycNextAction? action) => switch (action) {
    KycNextAction.verifyEmail =>
      'Add and verify your email address to start verification.',
    KycNextAction.verifyPhoneNumber =>
      'Add and verify your phone number to start verification.',
    KycNextAction.verifyIdentity => 'Verify your BVN or NIN to reach Tier 1.',
    KycNextAction.verifyGovernmentId =>
      'Verify a government-issued ID to reach Tier 2.',
    KycNextAction.uploadUtilityBill =>
      'Upload a recent utility bill to reach Tier 3.',
    KycNextAction.complete => 'All verification steps are complete.',
    KycNextAction.unknown || null => null,
  };

  String _identityDescription(KycVerificationStatus status) => switch (status) {
    KycVerificationStatus.success => 'Your identity has been verified.',
    KycVerificationStatus.pending =>
      'We have received your details and are checking them.',
    KycVerificationStatus.failed =>
      'The last attempt did not pass. You can try again.',
    _ => 'Matched against the issuing register automatically.',
  };

  String _utilityBillDescription(KycVerificationStatus status) =>
      switch (status) {
        KycVerificationStatus.success => 'Your address has been verified.',
        KycVerificationStatus.pending => 'Your bill is being reviewed.',
        KycVerificationStatus.failed =>
          'The last bill was not accepted. You can upload another.',
        _ => 'Upload a recent utility bill showing your address.',
      };

  String _governmentIdDescription(KycVerificationStatus status) =>
      switch (status) {
        KycVerificationStatus.success => 'Your document has been verified.',
        KycVerificationStatus.pending =>
          'We have received your document and are checking it.',
        KycVerificationStatus.failed =>
          'The last attempt did not pass. You can try again.',
        _ =>
          "Driver's licence, international passport, voter's card, or NIN "
              'slip.',
      };

  /// Manual refresh, beside an inline error when the last load failed.
  Widget _kycRefreshAction(NotifierState<KycStatusData> statusState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: statusState.isError
              ? Text(
                  statusState.message ?? 'Unable to load your latest status.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : const SizedBox.shrink(),
        ),
        TextButton.icon(
          onPressed: statusState.isLoading
              ? null
              : () => ref.read(kycAuthoritativeRefreshProvider)(),
          icon: const Icon(IconsaxPlusLinear.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _tiersScreen() {
    final state = ref.watch(userTierProvider);
    final profileState = ref.watch(userProfileProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(userTierProvider.notifier).load);
    }
    if (profileState.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(userProfileProvider.notifier).load);
    }
    // Warm the authoritative status here too, so the step screens opened from
    // this list already have it and the next action can be shown.
    final statusState = _watchKycStatus();
    final data = state.data;
    if (data == null) {
      return AppScaffold(
        title: 'Account tiers',
        activeSection: AppSection.account,
        onBack: _back,
        onSectionSelected: _goSection,
        body: Center(
          child: state.isError
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.message ?? 'Unable to load account tiers.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () =>
                            ref.read(userTierProvider.notifier).load(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final summary = data.currentTierSummary;
    return AppScaffold(
      title: 'Account tiers',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24).clearOfNav(context),
        children: [
          _kycRefreshAction(statusState),
          if (_nextActionMessage(statusState.data?.nextAction) case final next?)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: ApiStateCard(
                title: 'Next step',
                message: next,
                tone: ApiStateTone.info,
              ),
            ),
          Container(
            padding: const EdgeInsets.all(BocSpace.md),
            decoration: BoxDecoration(
              color: BocColors.navy,
              borderRadius: BorderRadius.circular(BocRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your current tier',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: BocColors.goldLight),
                ),
                const SizedBox(height: 14),
                LimitRow(label: 'Tier', value: summary.tierLabel),
                LimitRow(
                  label: 'Daily transfer limit',
                  value: summary.dailyTransferLimit.displayValue,
                ),
                LimitRow(
                  label: 'Max wallet balance',
                  value: summary.maxWalletBalance.displayValue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < data.tiers.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            if (_tierContactRequirement(profileState, data.tiers[index])
                case final requirement?) ...[
              requirement,
              const SizedBox(height: 12),
            ],
            TierCard(
              tier: data.tiers[index].tier,
              title: data.tiers[index].title,
              subtitle:
                  data.tiers[index].description ??
                  data.tiers[index].lockReason ??
                  'Tier requirements and account limits.',
              requirements: data.tiers[index].requirements
                  .map((requirement) => requirement.label)
                  .toList(growable: false),
              status: data.tiers[index].statusLabel,
              statusColor: switch (data.tiers[index].status) {
                TierCardStatus.verified => BocColors.green,
                TierCardStatus.inProgress => BocColors.gold,
                TierCardStatus.locked ||
                TierCardStatus.unknown => BocColors.grey,
              },
              leadingColor: switch (data.tiers[index].status) {
                TierCardStatus.verified => BocColors.green,
                TierCardStatus.inProgress => BocColors.gold,
                TierCardStatus.locked ||
                TierCardStatus.unknown => BocColors.grey,
              },
              actionLabel: data.tiers[index].actionLabel,
              lockReason: data.tiers[index].lockReason,
              onTap: _tierCardDestination(data.tiers[index]),
            ),
          ],
          const SizedBox(height: BocSpace.lg),
          SettingsGroup(
            caption: 'Business and income documents',
            padding: EdgeInsets.zero,
            children: [
              for (final (type, route, icon) in const [
                (
                  DocumentVerificationType.cac,
                  AppScreen.kycCacDocument,
                  IconsaxPlusLinear.building,
                ),
                (
                  DocumentVerificationType.bankStatement,
                  AppScreen.kycBankStatement,
                  IconsaxPlusLinear.receipt_item,
                ),
              ])
                SettingsTile(
                  icon: icon,
                  title: type.fieldLabel,
                  subtitle: 'PDF, maximum 10 MB',
                  onTap: () => _go(route),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _tierContactRequirement(
    NotifierState<UserOwnProfileData> profileState,
    TierCardData card,
  ) {
    final profile = profileState.data;
    if (card.tier != 1 ||
        card.status != TierCardStatus.inProgress ||
        profile == null ||
        areContactsReadyForKyc(profile)) {
      return null;
    }
    return _contactRequirementCard(profile);
  }

  /// Resolves what a tier card does when tapped.
  ///
  /// Routing keys off the documented tier number and card status only — never
  /// off `statusLabel`, `actionLabel`, or requirement text, which are display
  /// strings the backend may reword. A null result disables the card.
  VoidCallback? _tierCardDestination(TierCardData card) {
    switch (card.status) {
      case TierCardStatus.verified:
        // Already satisfied: reading the summary in place, no resubmission.
        return null;
      case TierCardStatus.inProgress:
        VoidCallback guarded(
          AppScreen screen,
          KycVerificationStatus? Function(KycStatusData) step,
        ) => () async {
          final status = ref.read(kycStatusProvider).data;
          final resuming =
              status != null && step(status) == KycVerificationStatus.pending;
          if ((resuming || await _ensureContactsForKyc()) && mounted) {
            _go(screen);
          }
        };

        return switch (card.tier) {
          1 => guarded(AppScreen.kycIdentity, (s) => s.identity.status),
          2 => guarded(AppScreen.kycGovernmentId, (s) => s.governmentId.status),
          3 => guarded(AppScreen.kycUtilityBill, (s) => s.utilityBill.status),
          _ => null,
        };
      case TierCardStatus.locked:
        // The card itself renders `lockReason`; no navigation, no toast.
        return null;
      case TierCardStatus.unknown:
        apiLogger.w({
          'event': 'UNKNOWN_TIER_CARD_STATUS',
          'tier': card.tier,
          'statusLabel': card.statusLabel,
        });
        return null;
    }
  }

  /// BVN/NIN verification.
  ///
  /// Reached from `/account/tier/bvn` and `/account/tier/nin`, which preselect
  /// the identity type. Neither route stands for a whole tier.
  Widget _kycIdentityScreen() {
    final flowState = ref.watch(identityVerificationProvider);
    final flow = flowState.data ?? const KycFlowData();
    final submitting = flowState.isLoading || _launchingKycCapture;
    final statusState = _watchKycStatus();
    final status = statusState.data?.identity;

    // The backend owns verification. The local stage only decides whether the
    // form is still usable.
    final serverStatus = status?.status ?? KycVerificationStatus.unknown;
    final pendingBvn =
        serverStatus == KycVerificationStatus.pending &&
        status?.identityType == IdentityType.bvn.wireValue;
    final localBvnResume =
        flow.initiation?.identityType == IdentityType.bvn.wireValue &&
        (flow.stage == KycFlowStage.awaitingProvider ||
            flow.stage == KycFlowStage.pendingReview ||
            flow.stage == KycFlowStage.failed);
    final initiated =
        serverStatus == KycVerificationStatus.pending ||
        serverStatus == KycVerificationStatus.success ||
        flow.stage == KycFlowStage.awaitingProvider;
    final showBvnResumeForm = pendingBvn || localBvnResume;
    final effectiveCardType = showBvnResumeForm
        ? IdentityType.bvn
        : _selectedIdentityType;

    return AppScaffold(
      title: 'Identity verification',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          Text(
            'Verify your BVN or NIN to raise your account tier. We match it '
            'against the issuing register — no documents to upload.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          VerificationCard(
            title: '${effectiveCardType.label} verification',
            description: _identityDescription(serverStatus),
            statusLabel: _statusLabel(serverStatus),
            statusColor: _statusColor(serverStatus),
            value: (status?.identityLast4 ?? flow.identityLast4) == null
                ? null
                : '${effectiveCardType.label} — '
                      '•••• ••• ${status?.identityLast4 ?? flow.identityLast4}',
          ),
          const SizedBox(height: 14),
          _kycRefreshAction(statusState),
          if (status?.failureReason != null) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Verification failed',
              message: status!.failureReason!,
              tone: ApiStateTone.blocked,
            ),
          ],
          const SizedBox(height: 14),
          if (serverStatus == KycVerificationStatus.success)
            const ApiStateCard(
              title: 'Identity verified',
              message: 'Your identity has been verified.',
              tone: ApiStateTone.info,
            )
          else if (initiated &&
              serverStatus != KycVerificationStatus.failed) ...[
            const ApiStateCard(
              title: 'Verification in progress',
              message:
                  'Your details have been submitted. Your tier updates '
                  'automatically once the check completes.',
              tone: ApiStateTone.info,
            ),
            if (showBvnResumeForm) ...[
              const SizedBox(height: 14),
              _identityForm(
                submitting,
                identityType: IdentityType.bvn,
                lockType: true,
                continuing: true,
              ),
            ],
          ] else
            _identityForm(
              submitting,
              identityType: _selectedIdentityType,
              lockType: false,
              continuing: false,
            ),
          if (flowState.isError &&
              flowState.message != null &&
              !_isContactRequiredError(flowState)) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Verification could not start',
              message: flowState.message!,
              tone: ApiStateTone.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _identityForm(
    bool submitting, {
    required IdentityType identityType,
    required bool lockType,
    required bool continuing,
  }) {
    // Resuming an attempt started before the contact rule is not a new start.
    if (!continuing) {
      if (_kycContactGate() case final gate?) return gate;
    }
    return SurfaceCard(
      child: Form(
        key: _identityFormKey,
        autovalidateMode: _identityAutovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm your identity number',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Enter the number linked to your legal name.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            FormDropdown<IdentityType>(
              label: 'Identity type',
              key: const ValueKey('identity-type'),
              value: identityType,
              items: kSupportedIdentityTypes
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(growable: false),
              onChanged: lockType || submitting
                  ? null
                  : (value) => refreshKycFormState(() {
                      if (value != null) _selectedIdentityType = value;
                    }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              key: const ValueKey('identity-number'),
              label: '${identityType.label} number',
              controller: _identityNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(kIdentityNumberLength),
              ],
              enabled: !submitting,
              validator: (value) => isValidIdentityNumber(value ?? '')
                  ? null
                  : 'Enter your $kIdentityNumberLength-digit '
                        '${identityType.label}.',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              key: const ValueKey('identity-submit'),
              label: submitting
                  ? 'Submitting…'
                  : continuing
                  ? 'Continue verification'
                  : 'Submit for verification',
              onPressed: submitting
                  ? null
                  : () => _submitIdentityVerification(identityType),
            ),
          ],
        ),
      ),
    );
  }

  /// Asks for consent before a provider job is created.
  ///
  /// Requested after the number is entered and before anything is initiated, so
  /// a refusal never leaves an orphaned job the backend would answer with 409.
  /// Returns null when the user declines.
  Future<KycCaptureConsent?> _requestIdentityConsent(
    IdentityType identityType,
  ) async {
    final granted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Consent to identity verification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To verify your ${identityType.label}, we share the '
                'following with our identity verification provider, which '
                'may be Dojah or Smile ID:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                '• Your personal details, including your name and '
                'date of birth',
              ),
              const SizedBox(height: 6),
              const Text('• Your contact information'),
              const SizedBox(height: 6),
              const Text(
                '• Your identity number and a photo of your face, '
                'taken on the next screen',
              ),
              const SizedBox(height: 12),
              Text(
                'Your photo is matched against the record held by the issuing '
                'authority. You can decline, but we cannot verify your '
                'identity without it.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('I agree'),
          ),
        ],
      ),
    );

    if (granted != true) return null;
    return KycCaptureConsent(grantedAtUtc: DateTime.now().toUtc());
  }

  Future<void> _submitIdentityVerification([
    IdentityType? requestedType,
  ]) async {
    if (_identityFormKey.currentState?.validate() != true) {
      refreshKycFormState(
        () => _identityAutovalidate = AutovalidateMode.onUserInteraction,
      );
      return;
    }

    final identityType = requestedType ?? _selectedIdentityType;
    final consent = await _requestIdentityConsent(identityType);
    if (!mounted) return;
    if (consent == null) {
      _showMessage(
        'Identity verification needs your consent before it can start.',
      );
      return;
    }

    _setLaunchingKycCapture(true);
    try {
      await _startIdentityVerification(identityType, consent);
    } finally {
      _setLaunchingKycCapture(false);
    }
  }

  Future<void> _startIdentityVerification(
    IdentityType identityType,
    KycCaptureConsent consent,
  ) async {
    // Held only until the SDK is handed it, then cleared below.
    final identityNumber = _identityNumberController.text.trim();
    final notifier = ref.read(identityVerificationProvider.notifier);
    final initiation = await notifier.submit(
      identityType: identityType,
      identityNumber: identityNumber,
    );
    if (!mounted) return;

    final result = ref.read(identityVerificationProvider);
    if (result.isError) {
      if (_isContactRequiredError(result)) {
        await _handleContactRequiredError(result);
        return;
      }
      _showErrorMessage(result.message ?? 'Verification could not start.');
      return;
    }

    if (initiation == null) {
      _identityNumberController.clear();
      // Reached only when a verification is already running and this process
      // still cannot reopen it. A blocking conflict arrives as an error above,
      // so it is never announced in a success style.
      _showMessage(
        result.message ??
            'A verification is already in progress. Pull to refresh for its '
                'latest status.',
      );
      return;
    }

    await _openIdentityCapture(
      notifier,
      initiation,
      identityType: identityType,
      identityNumber: identityNumber,
      consent: consent,
    );
  }

  Future<void> _openIdentityCapture(
    IdentityVerificationNotifier notifier,
    KycInitiationData initiation, {
    required IdentityType identityType,
    required String identityNumber,
    required KycCaptureConsent consent,
  }) async {
    final KycProvider provider;
    try {
      provider = validateKycLaunch(
        initiation,
        operation: KycOperation.identity,
        useSandbox: Env.isStaging,
        now: DateTime.now().toUtc(),
      );
    } on FormatException {
      notifier.markProviderFailure();
      _identityNumberController.clear();
      _showErrorMessage(
        'We could not start identity capture. Please contact support.',
      );
      return;
    }

    if (provider == KycProvider.dojah) {
      _identityNumberController.clear();
      final outcome = await _openDojahCapture(
        initiation,
        KycOperation.identity,
        bvn: identityType == IdentityType.bvn
            ? dojahCaptureBvn(
                identityNumber,
                environment: initiation.environment,
              )
            : null,
      );
      if (!mounted || outcome == null) return;
      await _handleIdentityCaptureOutcome(notifier, outcome);
      return;
    }

    final SmileIdBiometricJob job;
    try {
      job = SmileIdBiometricJob.fromInitiation(
        initiation,
        useSandbox: Env.isStaging,
        identityType: identityType,
        identityNumber: identityNumber,
        consent: consent,
      );
    } on SmileIdConfigurationException {
      // The backend created a job this build cannot launch — most likely it is
      // still issuing Enhanced KYC (job 5), which captures no selfie.
      notifier.markProviderFailure();
      _identityNumberController.clear();
      _showErrorMessage(
        'We could not start identity capture. Please contact support.',
      );
      return;
    }

    // The number is now inside the job the SDK will receive; stop holding it
    // in a live controller.
    _identityNumberController.clear();

    await _warmUpSmileId();
    if (!mounted) return;
    final outcome = await _pushKycCapture<SmileIdFlowOutcome>(
      SmileIdCaptureScreen(job: job),
    );
    if (!mounted) return;

    await _handleIdentityCaptureOutcome(notifier, switch (outcome ??
        SmileIdFlowOutcome.cancelled) {
      SmileIdFlowOutcome.submitted => KycCaptureOutcome.submitted,
      SmileIdFlowOutcome.cancelled => KycCaptureOutcome.cancelled,
      SmileIdFlowOutcome.failed => KycCaptureOutcome.failed,
    });
  }

  Future<void> _handleIdentityCaptureOutcome(
    IdentityVerificationNotifier notifier,
    KycCaptureOutcome outcome,
  ) async {
    switch (outcome) {
      case KycCaptureOutcome.submitted:
        notifier.markPendingReview();
        // There is nothing left to do on this form, so the user goes back to
        // the tier list they started from and watches it reload there rather
        // than waiting on a screen they are finished with.
        _returnToTierList();
        _showSuccessMessage(
          'Identity submitted. We will update you once it is checked.',
        );
        // Submitted is not verified; only the refreshed aggregates decide.
        await ref.read(kycAuthoritativeRefreshProvider)();
      case KycCaptureOutcome.cancelled:
        notifier.markAwaitingProvider();
      case KycCaptureOutcome.failed:
        notifier.markProviderFailure();
        _showErrorMessage('Identity capture failed. You can try again.');
      case KycCaptureOutcome.unknown:
        notifier.markReconciling();
        await ref.read(kycAuthoritativeRefreshProvider)();
        if (mounted) {
          _showMessage('Checking your identity verification status.');
        }
    }
  }

  /// Government-ID verification.
  ///
  /// Collects the document type and optional number, then initiates. Document
  /// capture itself runs in the provider SDK, which is not connected yet.
  Widget _kycGovernmentIdScreen() {
    final flowState = ref.watch(governmentIdVerificationProvider);
    final flow = flowState.data ?? const KycFlowData();
    final submitting = flowState.isLoading || _launchingKycCapture;
    final statusState = _watchKycStatus();
    final status = statusState.data?.governmentId;

    // The backend is authoritative. The local flow stage only decides whether
    // the form is still usable; it never renders a verified state.
    final serverStatus = status?.status ?? KycVerificationStatus.unknown;
    final initiated =
        serverStatus == KycVerificationStatus.pending ||
        serverStatus == KycVerificationStatus.success ||
        flow.stage == KycFlowStage.awaitingProvider ||
        flow.stage == KycFlowStage.pendingReview;

    return AppScaffold(
      title: 'Government ID',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          Text(
            'Verify a government-issued ID to raise your account tier.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          VerificationCard(
            title: 'Government ID',
            description: _governmentIdDescription(serverStatus),
            statusLabel: _statusLabel(serverStatus),
            statusColor: _statusColor(serverStatus),
            icon: IconsaxPlusLinear.personalcard,
            value: status?.documentNumberLast4 != null
                ? '•••• ${status!.documentNumberLast4}'
                : GovernmentIdDocumentType.tryParse(
                    status?.documentType,
                  )?.label,
          ),
          const SizedBox(height: 14),
          _kycRefreshAction(statusState),
          if (status?.failureReason != null) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Verification failed',
              message: status!.failureReason!,
              tone: ApiStateTone.blocked,
            ),
          ],
          const SizedBox(height: 14),
          if (serverStatus == KycVerificationStatus.success)
            const ApiStateCard(
              title: 'Document verified',
              message: 'Your government ID has been verified.',
              tone: ApiStateTone.info,
            )
          else if (initiated &&
              serverStatus != KycVerificationStatus.failed) ...[
            const ApiStateCard(
              title: 'Verification in progress',
              message:
                  'Your document has been submitted. Your tier updates '
                  'automatically once the check completes.',
              tone: ApiStateTone.info,
            ),
            const SizedBox(height: 14),
            _governmentIdFormSection(submitting, true),
          ] else
            _governmentIdFormSection(
              submitting,
              serverStatus == KycVerificationStatus.pending,
            ),
          if (flowState.isError &&
              flowState.message != null &&
              !_isContactRequiredError(flowState)) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Verification could not start',
              message: flowState.message!,
              tone: ApiStateTone.error,
            ),
          ],
        ],
      ),
    );
  }

  /// Documents the live catalogue offers that the configured government-ID
  /// provider can launch, in server order; null while configuration is not
  /// usable. The initiation's own provider is re-checked at launch.
  List<GovernmentIdDocumentOption>? _offeredGovernmentIdDocuments() {
    final config = ref.read(kycProviderConfigProvider).data;
    final catalogue = ref.read(governmentIdDocumentTypesProvider).data;
    if (config == null || catalogue == null) return null;
    final provider = config.governmentId.provider;
    return catalogue.documentTypes
        .where((option) => option.documentType.isEnabledFor(provider))
        .toList(growable: false);
  }

  /// The chosen option if the catalogue still offers it, otherwise the first
  /// offered one.
  GovernmentIdDocumentOption _resolveDocumentOption(
    List<GovernmentIdDocumentOption> offered,
  ) {
    for (final option in offered) {
      if (option.documentType == _selectedDocumentType) return option;
    }
    _selectedDocumentType = offered.first.documentType;
    return offered.first;
  }

  void _retryGovernmentIdConfiguration() {
    ref.read(kycProviderConfigProvider.notifier).load();
    ref.read(governmentIdDocumentTypesProvider.notifier).load();
  }

  Widget _governmentIdFormSection(bool submitting, bool pending) {
    if (!pending) {
      if (_kycContactGate() case final gate?) return gate;
    }
    final configState = ref.watch(kycProviderConfigProvider);
    final catalogueState = ref.watch(governmentIdDocumentTypesProvider);
    if (configState.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(kycProviderConfigProvider.notifier).load);
    }
    if (catalogueState.status == ServiceStatus.idle) {
      Future<void>.microtask(
        ref.read(governmentIdDocumentTypesProvider.notifier).load,
      );
    }

    final offered = _offeredGovernmentIdDocuments();
    if (offered == null && !configState.isError && !catalogueState.isError) {
      return const ApiLoadingSection(label: 'Loading document options');
    }
    if (offered == null || offered.isEmpty) {
      final loading = configState.isLoading || catalogueState.isLoading;
      return ApiStateCard(
        title: 'Document verification unavailable',
        message:
            'We could not load the documents you can verify with right now. '
            'Please try again.',
        tone: ApiStateTone.error,
        actionLabel: loading ? null : 'Retry',
        onAction: loading ? null : _retryGovernmentIdConfiguration,
      );
    }
    return _governmentIdForm(
      submitting,
      pending,
      offered,
      _resolveDocumentOption(offered),
    );
  }

  Widget _governmentIdForm(
    bool submitting,
    bool pending,
    List<GovernmentIdDocumentOption> offered,
    GovernmentIdDocumentOption selected,
  ) {
    final label = selected.displayLabel;
    return SurfaceCard(
      child: Form(
        key: _governmentIdFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Verify your document',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Have a current ID that matches your legal name ready.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            // Only documents the server currently accepts and the configured
            // provider can launch are offered, in server order. A backend that
            // answers the initiation with a different provider is caught at
            // launch.
            FormDropdown<GovernmentIdDocumentType>(
              label: 'Document type',
              value: selected.documentType,
              // Each option shows the catalogue label and description; the
              // closed field shows just the label.
              items: offered
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.documentType,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(option.displayLabel),
                            if (option.description.isNotEmpty)
                              Text(
                                option.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
              selectedItemBuilder: (context) => [
                for (final option in offered)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      option.displayLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: submitting
                  ? null
                  : (value) => refreshKycFormState(() {
                      if (value == null) return;
                      _selectedDocumentType = value;
                      final next = offered.firstWhere(
                        (option) => option.documentType == value,
                      );
                      // A number typed for a document that needed one must
                      // never travel with one that does not.
                      if (!next.requiresDocumentNumber) {
                        _documentNumberController.clear();
                      }
                    }),
            ),
            if (selected.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                selected.description,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.5),
              ),
            ],
            const SizedBox(height: 8),
            // The provider's own capture asks for the document again from its
            // configured list and is never told this choice. Naming it here
            // keeps the declared document and the captured one together.
            Text(
              'Select $label again when verification opens, so it matches '
              'what we record.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            if (selected.requiresDocumentNumber) ...[
              const SizedBox(height: 12),
              AppTextField(
                key: const ValueKey('document-number'),
                label: 'Document number',
                controller: _documentNumberController,
                enabled: !submitting,
                hintText: 'As printed on your $label',
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the document number as printed on your $label.'
                    : null,
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: switch ((submitting, pending)) {
                (true, _) => 'Starting…',
                (false, true) => 'Continue verification',
                (false, false) => 'Start verification',
              },
              onPressed: submitting ? null : _submitGovernmentId,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitGovernmentId() async {
    if (!(_governmentIdFormKey.currentState?.validate() ?? false)) return;

    _setLaunchingKycCapture(true);
    try {
      await _startGovernmentIdVerification();
    } finally {
      _setLaunchingKycCapture(false);
    }
  }

  Future<void> _startGovernmentIdVerification() async {
    // Never initiate without a current, usable configuration.
    final offered = _offeredGovernmentIdDocuments();
    if (offered == null || offered.isEmpty) return;
    final selected = _resolveDocumentOption(offered);

    final notifier = ref.read(governmentIdVerificationProvider.notifier);
    final initiation = await notifier.submit(
      documentType: selected.documentType,
      documentNumber: selected.requiresDocumentNumber
          ? _documentNumberController.text
          : null,
    );
    if (!mounted) return;

    final result = ref.read(governmentIdVerificationProvider);
    if (result.isError) {
      if (_isContactRequiredError(result)) {
        await _handleContactRequiredError(result);
        return;
      }
      _showErrorMessage(result.message ?? 'Verification could not start.');
      return;
    }

    if (initiation == null) {
      // A verification is already running and this process cannot reopen it.
      // Refresh is the only honest action; retrying would orphan the job.
      _showMessage(
        result.message ??
            'A verification is already in progress. Pull to refresh for its '
                'latest status.',
      );
      return;
    }

    await _openDocumentCapture(notifier, initiation);
  }

  Future<void> _openDocumentCapture(
    GovernmentIdVerificationNotifier notifier,
    KycInitiationData initiation,
  ) async {
    final KycProvider provider;
    try {
      provider = validateKycLaunch(
        initiation,
        operation: KycOperation.governmentId,
        useSandbox: Env.isStaging,
        now: DateTime.now().toUtc(),
      );
    } on FormatException {
      notifier.markProviderFailure();
      _showErrorMessage(
        'We could not start document capture. Please contact support.',
      );
      return;
    }

    // The provider is only known now. A document the user already chose can
    // be one this provider cannot verify, so say which one works instead of
    // launching a capture that must fail.
    final unsupported = governmentIdUnsupportedMessage(
      GovernmentIdDocumentType.tryParse(initiation.documentType),
      provider,
      offeredTypes:
          ref.read(governmentIdDocumentTypesProvider).data?.types ?? const [],
    );
    if (unsupported != null) {
      notifier.markProviderFailure();
      _showErrorMessage(unsupported);
      return;
    }

    if (provider == KycProvider.dojah) {
      final outcome = await _openDojahCapture(
        initiation,
        KycOperation.governmentId,
      );
      if (!mounted || outcome == null) return;
      await _handleDocumentCaptureOutcome(notifier, outcome);
      return;
    }

    final SmileIdDocumentJob job;
    try {
      job = SmileIdDocumentJob.fromInitiation(
        initiation,
        useSandbox: Env.isStaging,
      );
    } on SmileIdConfigurationException {
      // The backend created a job this build cannot launch. Never guess at the
      // missing values; the message deliberately omits the mismatch detail.
      notifier.markProviderFailure();
      _showErrorMessage(
        'We could not start document capture. Please contact support.',
      );
      return;
    }

    await _warmUpSmileId();
    if (!mounted) return;
    final outcome = await _pushKycCapture<SmileIdFlowOutcome>(
      SmileIdCaptureScreen(job: job),
    );
    if (!mounted) return;

    await _handleDocumentCaptureOutcome(notifier, switch (outcome ??
        SmileIdFlowOutcome.cancelled) {
      SmileIdFlowOutcome.submitted => KycCaptureOutcome.submitted,
      SmileIdFlowOutcome.cancelled => KycCaptureOutcome.cancelled,
      SmileIdFlowOutcome.failed => KycCaptureOutcome.failed,
    });
  }

  Future<KycCaptureOutcome?> _openDojahCapture(
    KycInitiationData initiation,
    KycOperation operation, {
    String? bvn,
  }) async {
    final config = ref.read(dojahConfigProvider);
    final widgetId = config.widgetIdFor(operation);
    final referenceId = initiation.referenceId?.trim() ?? '';
    if (widgetId.isEmpty || referenceId.isEmpty) {
      _showErrorMessage(
        'Dojah verification is not configured for this environment.',
      );
      return null;
    }
    // The flow has a required Email step. The address the user signed up
    // with satisfies it, so Dojah skips asking for what we already hold.
    final email = ref.read(userProfileProvider).data?.email;
    return _pushKycCapture<KycCaptureOutcome>(
      DojahCaptureScreen(
        widgetId: widgetId,
        referenceId: referenceId,
        operation: operation,
        bvn: bvn,
        email: email,
      ),
    );
  }

  /// Opens a capture screen and releases the submit button's busy state now
  /// that the screen covers it, so the form is usable again on return.
  Future<T?> _pushKycCapture<T>(Widget screen) {
    final closed = Navigator.of(
      context,
    ).push<T>(MaterialPageRoute(builder: (_) => screen));
    _setLaunchingKycCapture(false);
    return closed;
  }

  void _setLaunchingKycCapture(bool launching) {
    if (!mounted || _launchingKycCapture == launching) return;
    refreshKycFormState(() => _launchingKycCapture = launching);
  }

  /// Starts the Smile ID SDK while the submit button is still busy, so the
  /// capture screen opens ready instead of on a second spinner. A failure is
  /// left to that screen, which reports it and offers a retry.
  Future<void> _warmUpSmileId() async {
    try {
      await ref.read(smileIdGatewayProvider).ensureInitialized();
    } catch (_) {
      // Surfaced by SmileIdCaptureScreen's own initialization.
    }
  }

  Future<void> _handleDocumentCaptureOutcome(
    GovernmentIdVerificationNotifier notifier,
    KycCaptureOutcome outcome,
  ) async {
    switch (outcome) {
      case KycCaptureOutcome.submitted:
        notifier.markPendingReview();
        // Nothing is left to do on this form, so the user returns to the tier
        // list they started from and watches it reload there.
        _returnToTierList();
        _showSuccessMessage(
          'Document submitted. We will update you once it is reviewed.',
        );
        // Submitted means the job reached the provider, never verified. Only
        // the refreshed aggregates may move this card forward.
        // WidgetRef, not Ref, so the refresh object is read directly; the
        // refreshKycAuthoritativeState helper is for notifier call sites.
        await ref.read(kycAuthoritativeRefreshProvider)();
      case KycCaptureOutcome.cancelled:
        notifier.markAwaitingProvider();
      case KycCaptureOutcome.failed:
        notifier.markProviderFailure();
        _showErrorMessage('Document capture failed. You can try again.');
      case KycCaptureOutcome.unknown:
        notifier.markReconciling();
        await ref.read(kycAuthoritativeRefreshProvider)();
        if (mounted) {
          _showMessage('Checking your document verification status.');
        }
    }
  }

  /// Next of kin.
  ///
  /// No operation is published for this, so the screen states that plainly
  /// rather than collecting details it cannot submit.
  Widget _nextOfKinScreen() {
    return AppScaffold(
      title: 'Next of kin',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          Text(
            'Next of kin details are part of a later verification step.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          const ApiStateCard(
            title: 'Next of kin is not available yet',
            message:
                'There is no way to save these details yet, so we are not '
                'asking for them. We will enable this step once it is ready.',
            tone: ApiStateTone.blocked,
          ),
        ],
      ),
    );
  }

  /// Address and utility-bill verification.
  ///
  /// Runs initiate → signed PUT → complete. The terminal state is pending
  /// review, never verified.
  Widget _kycUtilityBillScreen() {
    final uploadState = ref.watch(utilityBillUploadProvider);
    final flow = uploadState.data ?? const KycFlowData();
    final busy = uploadState.isLoading;
    final statusState = _watchKycStatus();
    final status = statusState.data?.utilityBill;
    final serverStatus = status?.status ?? KycVerificationStatus.unknown;

    // A local pendingReview stage means this process submitted. The backend
    // may already know more than that, so the server status wins.
    final underReview =
        serverStatus == KycVerificationStatus.pending ||
        (flow.stage == KycFlowStage.pendingReview &&
            serverStatus != KycVerificationStatus.failed &&
            serverStatus != KycVerificationStatus.success);

    return AppScaffold(
      title: 'Address verification',
      // Keep the user in the flow while bytes are moving.
      showBottomNavigation: !busy,
      activeSection: AppSection.account,
      onBack: busy ? null : _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24).clearOfNav(context),
        children: [
          Text(
            'Confirm your address with a recent utility bill — not older than '
            'three months.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          VerificationCard(
            title: 'Address verification',
            description: _utilityBillDescription(serverStatus),
            statusLabel: _statusLabel(serverStatus),
            statusColor: _statusColor(serverStatus),
            icon: IconsaxPlusLinear.home_2,
          ),
          const SizedBox(height: 14),
          _kycRefreshAction(statusState),
          if (status?.failureReason != null) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Bill not accepted',
              message: status!.failureReason!,
              tone: ApiStateTone.blocked,
            ),
          ],
          // Free text from a manual reviewer; shown as written so the user
          // knows exactly what to change.
          if (status?.reviewNotes != null) ...[
            const SizedBox(height: 14),
            ApiStateCard(
              title: 'Reviewer notes',
              message: status!.reviewNotes!,
              tone: ApiStateTone.warning,
            ),
          ],
          const SizedBox(height: 14),
          if (serverStatus == KycVerificationStatus.success)
            const ApiStateCard(
              title: 'Address verified',
              message: 'Your address has been verified.',
              tone: ApiStateTone.info,
            )
          else if (underReview)
            ApiStateCard(
              title: 'Submitted for review',
              message:
                  uploadState.message ??
                  'We have received your utility bill. Your tier updates once '
                      'the review completes.',
              tone: ApiStateTone.info,
              actionLabel: 'Back to tiers',
              onAction: () => _go(AppScreen.tiers),
            )
          else ...[
            _utilityBillForm(flow, busy),
            if (uploadState.isError &&
                uploadState.message != null &&
                !_isContactRequiredError(uploadState)) ...[
              const SizedBox(height: 14),
              ApiStateCard(
                title: flow.uploadCompleted
                    ? 'Upload received, submission incomplete'
                    : 'Submission failed',
                message: uploadState.message!,
                tone: ApiStateTone.error,
                // A successful PUT means the bytes are already stored; only
                // the completion call needs repeating.
                actionLabel: flow.uploadCompleted ? 'Retry submission' : null,
                onAction: flow.uploadCompleted
                    ? () => ref
                          .read(utilityBillUploadProvider.notifier)
                          .retryCompletion()
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _utilityBillForm(KycFlowData flow, bool busy) {
    if (_kycContactGate() case final gate?) return gate;
    final bill = flow.selectedBill;
    return SurfaceCard(
      child: Form(
        key: _utilityBillFormKey,
        autovalidateMode: _utilityBillAutovalidate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Residential address',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Enter your address exactly as it appears on the bill.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Residential address',
              controller: _addressController,
              maxLines: 2,
              enabled: !busy,
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter your residential address.'
                  : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'State (optional)',
              controller: _addressStateController,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'LGA (optional)',
              controller: _lgaController,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Utility provider (optional)',
              controller: _utilityProviderController,
              enabled: !busy,
            ),
            const SizedBox(height: 12),
            FormDropdown<UtilityType?>(
              label: 'Meter type (optional)',
              value: _selectedUtilityType,
              items: [
                const DropdownMenuItem(child: Text('Not specified')),
                ...UtilityType.values.map(
                  (type) =>
                      DropdownMenuItem(value: type, child: Text(type.label)),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) =>
                        refreshKycFormState(() => _selectedUtilityType = value),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Meter / account number (optional)',
              controller: _utilityNumberController,
              enabled: !busy,
            ),
            const SizedBox(height: 18),
            Text(
              'Upload utility bill',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'A recent NEPA/PHCN, water, or waste bill.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            DashedLikeUpload(
              title: bill == null ? 'Choose document' : 'Change document',
              helperText: 'PDF, JPEG or PNG, maximum 10 MB',
              selectedFileName: bill?.fileName,
              enabled: !busy,
              loading: busy && flow.stage == KycFlowStage.uploading,
              onTap: _pickUtilityBill,
            ),
            if (busy) ...[
              const SizedBox(height: 12),
              ApiLoadingSection(
                label: _uploadStageLabel(flow.stage),
                compact: true,
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  _uploadStageLabel(flow.stage),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 18),
            PrimaryButton(
              label: busy ? _uploadStageLabel(flow.stage) : 'Submit for review',
              onPressed: busy || bill == null ? null : _submitUtilityBill,
            ),
            // Cancelling is only offered before bytes start moving.
            if (bill != null && !busy) ...[
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Remove selected file',
                onPressed: () => ref
                    .read(utilityBillUploadProvider.notifier)
                    .clearSelection(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _uploadStageLabel(KycFlowStage stage) => switch (stage) {
    KycFlowStage.requestingUpload => 'Preparing upload…',
    KycFlowStage.uploading => 'Uploading your document…',
    KycFlowStage.completing => 'Finishing submission…',
    _ => 'Working…',
  };

  Future<void> _pickUtilityBill() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kUtilityBillExtensions,
      withData: true,
    );
    if (!mounted) return;

    final picked = result?.files.singleOrNull;
    if (picked == null) return;

    final bytes = picked.bytes;
    final contentType = contentTypeForExtension(picked.extension);
    if (bytes == null || contentType == null) {
      _showErrorMessage('Choose a PDF, JPEG, or PNG file.');
      return;
    }

    ref
        .read(utilityBillUploadProvider.notifier)
        .selectBill(
          SelectedUtilityBill(
            fileName: picked.name,
            contentType: contentType,
            bytes: bytes,
          ),
        );
    if (!mounted) return;
    final state = ref.read(utilityBillUploadProvider);
    if (state.isError && state.message != null) {
      _showErrorMessage(state.message!);
    }
  }

  Future<void> _submitUtilityBill() async {
    if (_utilityBillFormKey.currentState?.validate() != true) {
      refreshKycFormState(
        () => _utilityBillAutovalidate = AutovalidateMode.onUserInteraction,
      );
      return;
    }

    await ref
        .read(utilityBillUploadProvider.notifier)
        .submit(
          residentialAddress: _addressController.text,
          residentialState: _addressStateController.text,
          residentialLga: _lgaController.text,
          utilityProvider: _utilityProviderController.text,
          utilityType: _selectedUtilityType,
          utilityNumber: _utilityNumberController.text,
        );
    if (!mounted) return;

    final result = ref.read(utilityBillUploadProvider);
    if (result.isDone) {
      _showSuccessMessage(result.message ?? 'Utility bill submitted.');
    } else if (result.isError) {
      if (_isContactRequiredError(result)) {
        await _handleContactRequiredError(result);
        return;
      }
      _showErrorMessage(result.message ?? 'Submission failed.');
    }
  }
}
