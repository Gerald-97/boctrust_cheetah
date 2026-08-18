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
              onTap: () => _showMessage(
                'Tier verification submission is not available in the current API.',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kycScaffold({
    required String title,
    required String subtitle,
    required int activeStep,
    required Widget body,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? stepLabel,
    String? secondaryButtonLabel,
    VoidCallback? onSecondaryPressed,
  }) {
    return AppScaffold(
      title: title,
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          const SurfaceCard(
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: BocColors.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preview only — the current API does not expose a tier-verification submission endpoint.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StepIndicator(activeStep: activeStep, label: stepLabel),
          const SizedBox(height: 18),
          body,
          const SizedBox(height: 18),
          PrimaryButton(label: buttonLabel, onPressed: onPressed),
          if (secondaryButtonLabel != null) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: secondaryButtonLabel,
              onPressed:
                  onSecondaryPressed ??
                  () => _showMessage('Next of kin form opened.'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tier1Screen() {
    return _kycScaffold(
      title: 'Tier 1 verification',
      subtitle:
          'Your BVN and a quick liveness check unlock basic transfers and Flex Save.',
      activeStep: 2,
      stepLabel: 'Liveness check',
      body: Column(
        children: [
          const VerificationCard(
            title: 'BVN verification',
            description:
                'Matched against CBN records automatically — no documents to upload.',
            value: 'BVN — •••• •••• 2214',
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live selfie capture',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Center your face in the frame and blink slowly — this matches your BVN photo.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 126,
                    height: 164,
                    decoration: BoxDecoration(
                      color: context.bocColors.goldPale,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(70),
                        bottom: Radius.circular(22),
                      ),
                      border: Border.all(
                        color: BocColors.gold,
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Icon(
                      Icons.face_rounded,
                      size: 52,
                      color: BocColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Good lighting, no glasses or face covering.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: BocColors.inkSoft),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      buttonLabel: 'Submission unavailable',
      onPressed: () => _showMessage(
        'Tier verification submission is not available in the current API.',
      ),
    );
  }

  Widget _tier2Screen() {
    return _kycScaffold(
      title: 'Tier 2 verification',
      subtitle:
          'Your NIN plus at least one next of kin unlocks higher limits and Target/Lock Save.',
      activeStep: 1,
      stepLabel: 'NIN verification',
      body: Column(
        children: [
          const VerificationCard(
            title: 'NIN verification',
            description: 'Matched against NIMC records automatically.',
            value: 'NIN — •••• •••• 8830',
          ),
          const SizedBox(height: 14),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm your NIN',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Enter the NIN linked to your legal name. This demo keeps the value local.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                const LabeledField(
                  label: 'Legal name',
                  value: 'Adaeze Okonkwo',
                ),
                const SizedBox(height: 12),
                const AppTextField(
                  label: 'National Identification Number',
                  initialValue: '•••• •••• 8830',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ],
      ),
      buttonLabel: 'Continue to next of kin',
      onPressed: () => _go(AppScreen.nextOfKin),
    );
  }

  Widget _nextOfKinScreen() {
    return _kycScaffold(
      title: 'Next of kin',
      subtitle:
          'Add someone BOCTrust can contact if we cannot reach you. This completes Tier 2.',
      activeStep: 2,
      stepLabel: 'Next of kin',
      body: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Use a trusted family member or close contact.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            const AppTextField(
              label: 'Full name',
              initialValue: 'Chioma Okonkwo',
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 12),
            const AppTextField(label: 'Relationship', initialValue: 'Sister'),
            const SizedBox(height: 12),
            const AppTextField(
              label: 'Phone number',
              initialValue: '0810 223 9981',
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
      buttonLabel: 'Submission unavailable',
      secondaryButtonLabel: '+ Add another next of kin',
      onPressed: () => _showMessage(
        'Tier verification submission is not available in the current API.',
      ),
      onSecondaryPressed: () =>
          _showMessage('Another next of kin can be added.'),
    );
  }

  Widget _tier3Screen() {
    return _kycScaffold(
      title: 'Tier 3 verification',
      subtitle:
          'Address verification and a utility bill unlock unlimited transfers and Group Save.',
      activeStep: 1,
      stepLabel: 'Address verification',
      body: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Residential address',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'Enter your address exactly as it appears on your utility bill.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 14),
            const AppTextField(
              label: 'Residential address',
              initialValue: '14 Ajose Adeogun Street, Utako, Abuja',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            const AppTextField(
              label: 'State / LGA',
              initialValue: 'FCT — Abuja Municipal',
            ),
            const SizedBox(height: 18),
            Text(
              'Upload utility bill',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'A recent NEPA/PHCN, water, or waste bill (not older than 3 months).',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 12),
            DashedLikeUpload(
              onTap: () => _showMessage('Document picker opened.'),
            ),
          ],
        ),
      ),
      buttonLabel: 'Submission unavailable',
      onPressed: () => _showMessage(
        'Tier verification submission is not available in the current API.',
      ),
    );
  }
}
