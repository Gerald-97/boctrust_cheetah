part of '../../app_flow/app_flow_navigator.dart';

extension KycScreens on AppFlowNavigatorState {
  Widget _tiersScreen() {
    final state = ref.watch(userTierProvider);
    if (state.status == ServiceStatus.idle) {
      Future<void>.microtask(ref.read(userTierProvider.notifier).load);
    }
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
    final initiated = flow.stage == KycFlowStage.awaitingProvider;

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
            description: initiated
                ? 'We have received your details and are checking them.'
                : 'Matched against the issuing register automatically.',
            statusLabel: initiated ? 'Pending' : 'Not started',
            statusColor: initiated ? BocColors.gold : BocColors.grey,
            value: flow.identityLastFour == null
                ? null
                : '${_selectedIdentityType.label} — '
                      '•••• ••• ${flow.identityLastFour}',
          ),
          const SizedBox(height: 14),
          if (initiated) ...[
            ApiStateCard(
              title: 'Verification in progress',
              message:
                  'Your ${_selectedIdentityType.label} has been submitted. '
                  'Your tier updates automatically once the check completes.',
              tone: ApiStateTone.info,
              actionLabel: 'Refresh status',
              onAction: () => ref
                  .read(identityVerificationProvider.notifier)
                  .refreshStatus(),
            ),
            const SizedBox(height: 14),
            // Identity capture beyond initiation is not wired yet: the
            // provider SDK needs dashboard configuration and a short-lived
            // token the API does not yet return.
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
                  : (value) => setState(() {
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
      setState(
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
  /// Blocked: the canonical `documentType` wire values are not published, so
  /// the app cannot offer a document list without guessing values the API
  /// would reject.
  Widget _kycGovernmentIdScreen() {
    return AppScaffold(
      title: 'Government ID',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Government ID verification raises your tier once it is connected.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          const ApiStateCard(
            title: 'Government ID is not available yet',
            message:
                'We are waiting on the list of accepted document types. '
                'Submitting one now could be rejected, so this step stays '
                'closed until it is ready.',
            tone: ApiStateTone.blocked,
          ),
          const SizedBox(height: 14),
          const VerificationCard(
            title: 'Government ID',
            description:
                "Driver's licence, international passport, voter's card, or "
                'NIN slip.',
            statusLabel: 'Unavailable',
            statusColor: BocColors.grey,
          ),
        ],
      ),
    );
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
  /// The initiate/upload/complete sequence lands in a later change; until then
  /// the screen does not collect an address it cannot submit.
  Widget _kycUtilityBillScreen() {
    return AppScaffold(
      title: 'Address verification',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Confirming your address with a recent utility bill raises your '
            'account tier.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          const ApiStateCard(
            title: 'Address verification is not connected yet',
            message:
                'Uploading a utility bill is not available in this release. '
                'We will enable it here once it is ready.',
            tone: ApiStateTone.blocked,
          ),
        ],
      ),
    );
  }
}
