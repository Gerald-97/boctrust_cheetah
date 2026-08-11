part of '../../app_flow/app_flow_navigator.dart';

extension KycScreens on AppFlowNavigatorState {
  Widget _tiersScreen() {
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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR CURRENT TIER',
                  style: TextStyle(
                    color: BocColors.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 14),
                LimitRow(label: 'Tier', value: 'Tier 1'),
                LimitRow(label: 'Daily transfer limit', value: '₦50,000'),
                LimitRow(label: 'Max wallet balance', value: '₦300,000'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TierCard(
            tier: 1,
            title: 'Tier 1',
            subtitle: 'Verify your BVN and complete a live selfie check.',
            requirements: const ['BVN', 'Liveness'],
            status: 'Verified',
            statusColor: BocColors.green,
            leadingColor: BocColors.green,
            onTap: () => _go(AppScreen.tier1),
          ),
          const SizedBox(height: 12),
          TierCard(
            tier: 2,
            title: 'Tier 2',
            subtitle: 'Verify your NIN and add at least one next of kin.',
            requirements: const ['NIN', 'Next of kin'],
            status: 'In progress · Continue',
            statusColor: BocColors.gold,
            leadingColor: BocColors.gold,
            onTap: () => _go(AppScreen.tier2),
          ),
          const SizedBox(height: 12),
          TierCard(
            tier: 3,
            title: 'Tier 3',
            subtitle: 'Verify your address and upload a recent utility bill.',
            requirements: const ['Address', 'Utility bill'],
            status: 'Locked until Tier 2 is complete',
            statusColor: BocColors.grey,
            leadingColor: BocColors.grey,
            onTap: () => _go(AppScreen.tier3),
          ),
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
              onPressed: () => _showMessage('Next of kin form opened.'),
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
      buttonLabel: 'Capture selfie & unlock Tier 1',
      onPressed: () => _showMessage('Tier 1 verification completed.'),
    );
  }

  Widget _tier2Screen() {
    return _kycScaffold(
      title: 'Tier 2 verification',
      subtitle:
          'Your NIN plus at least one next of kin unlocks higher limits and Target/Lock Save.',
      activeStep: 2,
      stepLabel: 'Next of kin',
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
                  'Next of kin',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Add someone we can contact if we cannot reach you.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 14),
                const LabeledField(label: 'Full name', value: 'Chioma Okonkwo'),
                const SizedBox(height: 12),
                const LabeledField(
                  label: 'Relationship',
                  value: 'Sister · 0810 223 9981',
                ),
              ],
            ),
          ),
        ],
      ),
      buttonLabel: 'Save & unlock Tier 2',
      secondaryButtonLabel: '+ Add another next of kin',
      onPressed: () => _showMessage('Tier 2 verification submitted.'),
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
      buttonLabel: 'Submit & unlock Tier 3',
      onPressed: () => _showMessage('Tier 3 verification submitted.'),
    );
  }
}
