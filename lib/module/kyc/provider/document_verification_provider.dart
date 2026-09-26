import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/document_verification_models.dart';

/// Draft state per document type. Selection and validation work without a
/// backend; nothing here reaches `submitted`, because no upload contract
/// exists yet and the submit action is gated by the type's capability.
final documentVerificationProvider =
    NotifierProvider.family<
      DocumentVerificationNotifier,
      DocumentVerificationState,
      DocumentVerificationType
    >(DocumentVerificationNotifier.new);

class DocumentVerificationNotifier extends Notifier<DocumentVerificationState> {
  DocumentVerificationNotifier(this.type);

  final DocumentVerificationType type;

  @override
  DocumentVerificationState build() => const DocumentVerificationState();

  /// Accepts a PDF up to 10 MB; anything else keeps the previous selection
  /// and reports why.
  void select({
    required String fileName,
    required String? extension,
    required int sizeBytes,
  }) {
    if (extension?.toLowerCase() != 'pdf') {
      state = DocumentVerificationState(
        document: state.document,
        error: 'Choose a PDF file.',
      );
      return;
    }
    if (sizeBytes > kDocumentMaxBytes) {
      state = DocumentVerificationState(
        document: state.document,
        error: 'Choose a file smaller than 10 MB.',
      );
      return;
    }
    state = DocumentVerificationState(
      document: SelectedDocument(fileName: fileName, sizeBytes: sizeBytes),
    );
  }

  void clearSelection() => state = const DocumentVerificationState();
}
