import 'package:boctrust_savings_loan/module/kyc/model/kyc_configuration_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_provider_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _operation({
  String provider = 'dojah',
  String product = 'government_id_verification',
  String sdkJobType = 'dojahGovernmentId',
  String jobType = 'government_id',
}) => {
  'provider': provider,
  'product': product,
  'sdkJobType': sdkJobType,
  'jobType': jobType,
  'callbackUrl': null,
};

Map<String, Object?> _providerConfig({
  Object? activeProvider = 'smile_id',
  Object? environment = 'sandbox',
  Map<String, Object?>? governmentId,
}) => {
  'activeProvider': activeProvider,
  'environment': environment,
  'identity': _operation(
    provider: 'smile_id',
    product: 'biometric_kyc',
    sdkJobType: 'biometricKyc',
    jobType: '1',
  ),
  'governmentId': governmentId ?? _operation(),
};

Map<String, Object?> _row(
  Object? value, {
  Object? label = 'Server label',
  Object? description = 'A description.',
  Object? requiresDocumentNumber = false,
  Object? active = true,
}) => {
  'value': value,
  'label': label,
  'description': description,
  'requiresDocumentNumber': requiresDocumentNumber,
  'active': active,
};

void main() {
  group('KycProviderConfigData', () {
    test('parses the active provider, environment and operations', () {
      final config = KycProviderConfigData.fromJson(_providerConfig());

      expect(config.activeProvider, KycProvider.smileId);
      expect(config.environment, KycProviderEnvironment.sandbox);
      expect(config.identity.provider, KycProvider.smileId);
      expect(config.identity.product, 'biometric_kyc');
      expect(config.governmentId.provider, KycProvider.dojah);
      expect(config.governmentId.sdkJobType, 'dojahGovernmentId');
      expect(config.governmentId.jobType, 'government_id');
    });

    test('reads the live environment', () {
      expect(
        KycProviderConfigData.fromJson(
          _providerConfig(environment: 'live'),
        ).environment,
        KycProviderEnvironment.live,
      );
    });

    test('tolerates a callback URL without keeping it', () {
      final config = KycProviderConfigData.fromJson(
        _providerConfig(
          governmentId: {
            ..._operation(),
            'callbackUrl': 'https://user.example.test/webhook',
          },
        ),
      );
      expect(config.governmentId.provider, KycProvider.dojah);
      expect(config.props.toString(), isNot(contains('webhook')));
      expect(config.governmentId.props.toString(), isNot(contains('webhook')));
    });

    test('rejects an unknown provider', () {
      expect(
        () => KycProviderConfigData.fromJson(
          _providerConfig(activeProvider: 'acme'),
        ),
        throwsFormatException,
      );
      expect(
        () => KycProviderConfigData.fromJson(
          _providerConfig(governmentId: _operation(provider: 'acme')),
        ),
        throwsFormatException,
      );
    });

    test('rejects an unknown or missing environment', () {
      for (final environment in ['production', 'staging', '', null, 1]) {
        expect(
          () => KycProviderConfigData.fromJson(
            _providerConfig(environment: environment),
          ),
          throwsFormatException,
          reason: '$environment',
        );
      }
    });

    test('rejects blank operation fields and non-map payloads', () {
      expect(
        () => KycProviderConfigData.fromJson(
          _providerConfig(governmentId: _operation(product: '  ')),
        ),
        throwsFormatException,
      );
      expect(
        () => KycProviderConfigData.fromJson('not a map'),
        throwsFormatException,
      );
      expect(
        () => KycProviderConfigData.fromJson({
          ..._providerConfig(),
          'identity': null,
        }),
        throwsFormatException,
      );
    });
  });

  group('GovernmentIdDocumentCatalogue', () {
    Map<String, Object?> catalogue(List<Object?> rows) => {
      'documentTypes': rows,
    };

    test('keeps active known rows in server order', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([
          _row('international_passport', label: 'International Passport'),
          _row('drivers_license', label: "Driver's License"),
          _row('voter_id', label: "Voter's Card"),
          _row('national_id', label: 'National ID'),
          _row('nin_slip', label: 'NIN Slip', requiresDocumentNumber: true),
        ]),
      );

      expect(parsed.types, [
        GovernmentIdDocumentType.internationalPassport,
        GovernmentIdDocumentType.driversLicense,
        GovernmentIdDocumentType.voterId,
        GovernmentIdDocumentType.nationalId,
        GovernmentIdDocumentType.ninSlip,
      ]);
      expect(parsed.documentTypes.last.requiresDocumentNumber, isTrue);
      expect(parsed.documentTypes.first.requiresDocumentNumber, isFalse);
      expect(parsed.documentTypes.first.description, 'A description.');
    });

    test('national_id always displays the exact NIN label', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([_row('national_id', label: 'National ID')]),
      );
      final option = parsed.documentTypes.single;

      expect(option.serverLabel, 'National ID');
      expect(option.displayLabel, 'NIN, National Identity Number');
    });

    test('other rows display the trimmed server label', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([_row('nin_slip', label: '  NIN Slip  ')]),
      );
      expect(parsed.documentTypes.single.displayLabel, 'NIN Slip');
    });

    test('drops inactive, unknown, blank-label and malformed rows', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([
          _row('voter_id', active: false),
          _row('passport'),
          _row('drivers_license', label: '   '),
          _row('international_passport', requiresDocumentNumber: 'yes'),
          _row('nin_slip', description: 7),
          'not a row',
          null,
          _row('national_id'),
        ]),
      );
      expect(parsed.types, [GovernmentIdDocumentType.nationalId]);
    });

    test('keeps the first valid duplicate', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([
          _row('voter_id', label: '   '),
          _row('voter_id', label: 'First'),
          _row('voter_id', label: 'Second', requiresDocumentNumber: true),
        ]),
      );
      expect(parsed.documentTypes.single.serverLabel, 'First');
      expect(parsed.documentTypes.single.requiresDocumentNumber, isFalse);
    });

    test('returns an immutable list', () {
      final parsed = GovernmentIdDocumentCatalogue.fromJson(
        catalogue([_row('voter_id')]),
      );
      expect(
        () => parsed.documentTypes.add(parsed.documentTypes.first),
        throwsUnsupportedError,
      );
    });

    test('a catalogue with no usable rows is a format error', () {
      for (final payload in <Object?>[
        catalogue([]),
        catalogue([_row('passport'), _row('voter_id', active: false)]),
        {'documentTypes': 'nope'},
        {'other': []},
        null,
      ]) {
        expect(
          () => GovernmentIdDocumentCatalogue.fromJson(payload),
          throwsFormatException,
          reason: '$payload',
        );
      }
    });
  });
}
