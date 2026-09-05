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
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _tiersScreen() {
    final state = ref.watch(userTierProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(userTierProvider.notifier).load);
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            decoration: BoxDecoration(
              color: BocColors.navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR CURRENT TIER',
                  style: TextStyle(
                    color: BocColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
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
        ],
      ),
    );
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
        return switch (card.tier) {
          1 => () => _go(AppScreen.kycIdentity),
          2 => () => _go(AppScreen.kycGovernmentId),
          3 => () => _go(AppScreen.kycUtilityBill),
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
    final submitting = flowState.isLoading;
    final statusState = _watchKycStatus();
    final status = statusState.data?.identity;

    // The backend owns verification. The local stage only decides whether the
    // form is still usable.
    final serverStatus = status?.status ?? KycVerificationStatus.unknown;
    final initiated =
        serverStatus == KycVerificationStatus.pending ||
        serverStatus == KycVerificationStatus.success ||
        flow.stage == KycFlowStage.awaitingProvider;

    return AppScaffold(
      title: 'Identity verification',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            title: '${_selectedIdentityType.label} verification',
            description: _identityDescription(serverStatus),
            statusLabel: _statusLabel(serverStatus),
            statusColor: _statusColor(serverStatus),
            value: (status?.identityLast4 ?? flow.identityLast4) == null
                ? null
                : '${_selectedIdentityType.label} — '
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
            const SizedBox(height: 14),
            // Tier 1 liveness needs a separate Smile product the backend has
            // not named yet; Enhanced KYC job 5 captures no selfie.
            const ApiStateCard(
              title: 'Identity capture not available yet',
              message:
                  'Guided photo capture is not connected in this release. If '
                  'the check needs more from you, we will let you know.',
              tone: ApiStateTone.blocked,
            ),
          ] else
            _identityForm(submitting),
          if (flowState.isError && flowState.message != null) ...[
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

  Widget _identityForm(bool submitting) {
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
              value: _selectedIdentityType,
              items: IdentityType.values
                  .map(
                    (type) =>
                        DropdownMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(growable: false),
              onChanged: submitting
                  ? null
                  : (value) => refreshKycFormState(() {
                      if (value != null) _selectedIdentityType = value;
                    }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: '${_selectedIdentityType.label} number',
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
                        '${_selectedIdentityType.label}.',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: submitting ? 'Submitting…' : 'Submit for verification',
              onPressed: submitting ? null : _submitIdentityVerification,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitIdentityVerification() async {
    if (_identityFormKey.currentState?.validate() != true) {
      refreshKycFormState(
        () => _identityAutovalidate = AutovalidateMode.onUserInteraction,
      );
      return;
    }
    final notifier = ref.read(identityVerificationProvider.notifier);
    await notifier.submit(
      identityType: _selectedIdentityType,
      identityNumber: _identityNumberController.text,
    );
    if (!mounted) return;

    final result = ref.read(identityVerificationProvider);
    if (result.isDone) {
      // The identity number is sensitive and already submitted; do not keep
      // it in a live controller.
      _identityNumberController.clear();
      _showSuccessMessage(result.message ?? 'Verification submitted.');
    } else if (result.isError) {
      _showErrorMessage(result.message ?? 'Verification could not start.');
    }
  }

  /// Government-ID verification.
  ///
  /// Collects the document type and optional number, then initiates. Document
  /// capture itself runs in the provider SDK, which is not connected yet.
  Widget _kycGovernmentIdScreen() {
    final flowState = ref.watch(governmentIdVerificationProvider);
    final flow = flowState.data ?? const KycFlowData();
    final submitting = flowState.isLoading;
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            icon: Icons.badge_outlined,
            value: status?.documentNumberLast4 != null
                ? '•••• ${status!.documentNumberLast4}'
                : (initiated ? _selectedDocumentType.label : null),
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
            _governmentIdForm(submitting),
          ] else
            _governmentIdForm(submitting),
          if (flowState.isError && flowState.message != null) ...[
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

  Widget _governmentIdForm(bool submitting) {
    return SurfaceCard(
      child: Form(
        key: _governmentIdFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your document',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Use a document that is current and matches your legal name.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            FormDropdown<GovernmentIdDocumentType>(
              label: 'Document type',
              value: _selectedDocumentType,
              items: GovernmentIdDocumentType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      enabled: type.isEnhancedDocumentVerificationEnabled,
                      child: Text(
                        type.isEnhancedDocumentVerificationEnabled
                            ? type.label
                            : '${type.label} — not supported for this '
                                  'verification method',
                        style: type.isEnhancedDocumentVerificationEnabled
                            ? null
                            : TextStyle(color: Theme.of(context).disabledColor),
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: submitting
                  ? null
                  : (value) => refreshKycFormState(() {
                      if (value != null &&
                          value.isEnhancedDocumentVerificationEnabled) {
                        _selectedDocumentType = value;
                      }
                    }),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'Document number (optional)',
              controller: _documentNumberController,
              enabled: !submitting,
              hintText: 'As printed on the document',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: submitting ? 'Submitting…' : 'Submit for verification',
              onPressed: submitting ? null : _submitGovernmentId,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitGovernmentId() async {
    final notifier = ref.read(governmentIdVerificationProvider.notifier);
    final initiation = await notifier.submit(
      documentType: _selectedDocumentType,
      documentNumber: _documentNumberController.text,
    );
    if (!mounted) return;

    final result = ref.read(governmentIdVerificationProvider);
    if (result.isError) {
      _showErrorMessage(result.message ?? 'Verification could not start.');
      return;
    }

    // The document number is never held while the camera is open.
    _documentNumberController.clear();

    if (initiation == null) {
      // A verification is already running and this process cannot reopen it.
      // Refresh is the only honest action; retrying would orphan the job.
      _showSuccessMessage(
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

    final outcome = await Navigator.of(context).push<SmileIdFlowOutcome>(
      MaterialPageRoute(
        builder: (_) => SmileIdEnhancedDocumentScreen(job: job),
      ),
    );
    if (!mounted) return;

    switch (outcome ?? SmileIdFlowOutcome.cancelled) {
      case SmileIdFlowOutcome.submitted:
        notifier.markPendingReview();
        // Submitted means the job reached Smile, never verified. Only the
        // refreshed aggregates may move this card forward.
        // WidgetRef, not Ref, so the refresh object is read directly; the
        // refreshKycAuthoritativeState helper is for notifier call sites.
        await ref.read(kycAuthoritativeRefreshProvider)();
        if (!mounted) return;
        _showSuccessMessage(
          'Document submitted. We will update you once it is reviewed.',
        );
      case SmileIdFlowOutcome.cancelled:
        notifier.markAwaitingProvider();
      case SmileIdFlowOutcome.failed:
        notifier.markProviderFailure();
        _showErrorMessage('Document capture failed. You can try again.');
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
            icon: Icons.home_outlined,
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
            if (uploadState.isError && uploadState.message != null) ...[
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
      _showErrorMessage(result.message ?? 'Submission failed.');
    }
  }
}
