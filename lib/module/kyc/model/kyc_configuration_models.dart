import 'package:equatable/equatable.dart';

import 'kyc_models.dart';
import 'kyc_provider_models.dart';

/// Provider environment published by `GET /users/me/kyc/provider-config`.
enum KycProviderEnvironment {
  sandbox('sandbox'),
  live('live');

  const KycProviderEnvironment(this.wireValue);
  final String wireValue;

  static KycProviderEnvironment? tryParse(Object? value) {
    for (final environment in values) {
      if (environment.wireValue == value) return environment;
    }
    return null;
  }
}

String _requireText(Object? value, String field) {
  final text = value is String ? value.trim() : '';
  if (text.isEmpty) throw FormatException('Missing $field.');
  return text;
}

Map<String, Object?> _requireMap(Object? value, String field) {
  if (value is! Map) throw FormatException('Missing $field.');
  return Map<String, Object?>.from(value);
}

KycProvider _requireProvider(Object? value, String field) =>
    KycProvider.tryParse(value) ?? (throw FormatException('Unknown $field.'));

/// The provider and job the backend will use for one KYC operation.
///
/// The published `callbackUrl` is deliberately not kept: the form never uses
/// it, and app state should not hold webhook addresses.
class KycProviderOperationConfig extends Equatable {
  const KycProviderOperationConfig({
    required this.provider,
    required this.product,
    required this.sdkJobType,
    required this.jobType,
  });

  factory KycProviderOperationConfig.fromJson(Object? json, String field) {
    final map = _requireMap(json, field);
    return KycProviderOperationConfig(
      provider: _requireProvider(map['provider'], '$field.provider'),
      product: _requireText(map['product'], '$field.product'),
      sdkJobType: _requireText(map['sdkJobType'], '$field.sdkJobType'),
      jobType: _requireText(map['jobType'], '$field.jobType'),
    );
  }

  final KycProvider provider;
  final String product;
  final String sdkJobType;
  final String jobType;

  @override
  List<Object?> get props => [provider, product, sdkJobType, jobType];
}

/// The KYC provider configuration currently active for this customer.
///
/// It assists preflight document filtering only. The provider returned by an
/// initiation remains authoritative for that attempt.
class KycProviderConfigData extends Equatable {
  const KycProviderConfigData({
    required this.activeProvider,
    required this.environment,
    required this.identity,
    required this.governmentId,
  });

  factory KycProviderConfigData.fromJson(Object? json) {
    final map = _requireMap(json, 'provider config');
    return KycProviderConfigData(
      activeProvider: _requireProvider(map['activeProvider'], 'activeProvider'),
      environment:
          KycProviderEnvironment.tryParse(map['environment']) ??
          (throw const FormatException('Unknown environment.')),
      identity: KycProviderOperationConfig.fromJson(
        map['identity'],
        'identity',
      ),
      governmentId: KycProviderOperationConfig.fromJson(
        map['governmentId'],
        'governmentId',
      ),
    );
  }

  final KycProvider activeProvider;
  final KycProviderEnvironment environment;
  final KycProviderOperationConfig identity;
  final KycProviderOperationConfig governmentId;

  @override
  List<Object?> get props => [
    activeProvider,
    environment,
    identity,
    governmentId,
  ];
}

/// One active government document the server currently accepts.
class GovernmentIdDocumentOption extends Equatable {
  const GovernmentIdDocumentOption({
    required this.documentType,
    required this.serverLabel,
    required this.description,
    required this.requiresDocumentNumber,
  });

  final GovernmentIdDocumentType documentType;
  final String serverLabel;
  final String description;
  final bool requiresDocumentNumber;

  /// Customer-facing name. `national_id` always uses the exact local NIN
  /// label so it can never be confused with the NIN slip.
  String get displayLabel => documentType == GovernmentIdDocumentType.nationalId
      ? documentType.label
      : serverLabel;

  /// The option a well-formed active row describes, or null for a row this
  /// build must not offer.
  static GovernmentIdDocumentOption? tryParse(Object? json) {
    if (json is! Map) return null;
    final documentType = GovernmentIdDocumentType.tryParse(json['value']);
    final label = json['label'];
    final description = json['description'];
    final requiresNumber = json['requiresDocumentNumber'];
    if (documentType == null ||
        json['active'] != true ||
        label is! String ||
        label.trim().isEmpty ||
        description is! String ||
        requiresNumber is! bool) {
      return null;
    }
    return GovernmentIdDocumentOption(
      documentType: documentType,
      serverLabel: label.trim(),
      description: description.trim(),
      requiresDocumentNumber: requiresNumber,
    );
  }

  @override
  List<Object?> get props => [
    documentType,
    serverLabel,
    description,
    requiresDocumentNumber,
  ];
}

/// The government documents the server currently accepts, in server order.
///
/// Inactive, unknown, malformed and duplicate rows are dropped without
/// discarding their valid siblings. A catalogue with nothing usable is a
/// format error, so the form can never be enabled with an empty choice.
class GovernmentIdDocumentCatalogue extends Equatable {
  const GovernmentIdDocumentCatalogue(this.documentTypes);

  factory GovernmentIdDocumentCatalogue.fromJson(Object? json) {
    final rows = _requireMap(json, 'document catalogue')['documentTypes'];
    if (rows is! List) throw const FormatException('Missing documentTypes.');
    final seen = <GovernmentIdDocumentType>{};
    final options = <GovernmentIdDocumentOption>[];
    for (final row in rows) {
      final option = GovernmentIdDocumentOption.tryParse(row);
      if (option != null && seen.add(option.documentType)) options.add(option);
    }
    if (options.isEmpty) {
      throw const FormatException('No usable government documents.');
    }
    return GovernmentIdDocumentCatalogue(List.unmodifiable(options));
  }

  final List<GovernmentIdDocumentOption> documentTypes;

  List<GovernmentIdDocumentType> get types => [
    for (final option in documentTypes) option.documentType,
  ];

  @override
  List<Object?> get props => [documentTypes];
}
