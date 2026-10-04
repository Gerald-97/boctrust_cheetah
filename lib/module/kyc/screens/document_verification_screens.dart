part of 'kyc_screens.dart';

/// CAC certificate and bank statement upload. File choice and validation
/// work now; submitting opens the unavailable sheet until each type's upload
/// contract exists, so no pending or success state can be reached.
extension DocumentVerificationScreens on KycScreenState {
  Widget _documentVerificationScreen(DocumentVerificationType type) {
    _assertPlaceholderFor(type.capability, FeatureAvailability.unavailable);
    final state = ref.watch(documentVerificationProvider(type));
    final theme = Theme.of(context);
    final document = state.document;
    final error = state.error;
    return AppScaffold(
      title: 'KYC verification',
      activeSection: AppSection.account,
      onBack: _back,
      onSectionSelected: _goSection,
      showBottomNavigation: false,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                BocSpace.gutter,
                BocSpace.xs,
                BocSpace.gutter,
                BocSpace.lg,
              ),
              children: [
                Semantics(
                  header: true,
                  child: Text(type.title, style: theme.textTheme.headlineSmall),
                ),
                const SizedBox(height: BocSpace.xs),
                Text(type.description, style: theme.textTheme.bodyMedium),
                const SizedBox(height: BocSpace.lg),
                Text(type.fieldLabel, style: theme.textTheme.labelMedium),
                const SizedBox(height: BocSpace.xs),
                DashedLikeUpload(
                  title: document == null ? 'Choose file' : 'Change file',
                  helperText: 'PDF, maximum 10 MB',
                  selectedFileName: document?.fileName,
                  onTap: () => _pickVerificationDocument(type),
                ),
                if (error != null) ...[
                  const SizedBox(height: BocSpace.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.bocColors.errorText,
                      ),
                    ),
                  ),
                ],
                if (document != null) ...[
                  const SizedBox(height: BocSpace.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BocTextButton(
                      label: 'Remove file',
                      onPressed: () => ref
                          .read(documentVerificationProvider(type).notifier)
                          .clearSelection(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              BocSpace.gutter,
              0,
              BocSpace.gutter,
              BocSpace.md,
            ),
            child: PrimaryButton(
              label: 'Upload document',
              onPressed: document == null
                  ? null
                  : () => BocUnavailableSheet.show(
                      context,
                      title: 'Document upload is not available yet',
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickVerificationDocument(DocumentVerificationType type) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (!mounted) return;
    final picked = result?.files.singleOrNull;
    if (picked == null) return;
    ref
        .read(documentVerificationProvider(type).notifier)
        .select(
          fileName: picked.name,
          extension: picked.extension,
          sizeBytes: picked.size,
        );
  }
}
