import 'package:equatable/equatable.dart';

import '../../../app/feature_capability.dart';

enum DocumentVerificationType {
  cac(
    capability: FeatureCapability.kycCacDocument,
    title: 'Upload your CAC certificate',
    description:
        'A valid Corporate Affairs Commission certificate showing your '
        'business is registered in Nigeria.',
    fieldLabel: 'CAC certificate',
  ),
  bankStatement(
    capability: FeatureCapability.kycBankStatement,
    title: 'Upload a bank statement',
    description:
        'A statement from the last 3 months showing your name, account '
        'number and transactions.',
    fieldLabel: 'Bank statement',
  );

  const DocumentVerificationType({
    required this.capability,
    required this.title,
    required this.description,
    required this.fieldLabel,
  });

  final FeatureCapability capability;
  final String title;
  final String description;
  final String fieldLabel;
}

/// `submitted` and later states only follow a server-confirmed submission,
/// which cannot happen while the type's capability is unavailable.
enum DocumentVerificationStatus {
  unsupported,
  draft,
  uploading,
  submitted,
  approved,
  rejected,
}

/// The document a customer has chosen. Only its name and size are kept; the
/// bytes are read again at upload time once an upload contract exists.
class SelectedDocument extends Equatable {
  const SelectedDocument({required this.fileName, required this.sizeBytes});

  final String fileName;
  final int sizeBytes;

  @override
  List<Object?> get props => [fileName, sizeBytes];
}

class DocumentVerificationState extends Equatable {
  const DocumentVerificationState({
    this.status = DocumentVerificationStatus.draft,
    this.document,
    this.error,
  });

  final DocumentVerificationStatus status;
  final SelectedDocument? document;
  final String? error;

  @override
  List<Object?> get props => [status, document, error];
}

const kDocumentMaxBytes = 10 * 1024 * 1024;
