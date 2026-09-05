import 'package:boctrust_savings_loan/module/account/model/profile_image_model.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/kyc/model/kyc_models.dart';
import 'package:boctrust_savings_loan/utils/utils.dart';
import 'package:flutter_test/flutter_test.dart';

/// Covers the places where a client-side mistake would silently misstate an
/// API-authoritative value: money formatting, signed-URL validation, and
/// status parsing. These are cheap to get wrong and expensive to notice.
void main() {
  group('formatApiAmount', () {
    test('groups a decimal string without parsing to double', () {
      expect(formatApiAmount('1248530.75', currency: 'NGN'), '₦1,248,530.75');
      expect(formatApiAmount('0.00', currency: 'NGN'), '₦0.00');
      expect(formatApiAmount('999', currency: 'NGN'), '₦999');
      expect(formatApiAmount('1000', currency: 'NGN'), '₦1,000');
      expect(formatApiAmount('1000000', currency: 'NGN'), '₦1,000,000');
      expect(formatApiAmount('-2500.50', currency: 'NGN'), '-₦2,500.50');
    });

    test('preserves precision a double round-trip would destroy', () {
      // Beyond 2^53: parsing to double and back would change this value.
      expect(
        formatApiAmount('9007199254740993.01', currency: 'NGN'),
        '₦9,007,199,254,740,993.01',
      );
      // Trailing decimal digits are preserved exactly as sent.
      expect(formatApiAmount('0.10', currency: 'NGN'), '₦0.10');
      expect(formatApiAmount('1.005', currency: 'NGN'), '₦1.005');
    });

    test('falls back to a currency suffix when the symbol is unknown', () {
      expect(formatApiAmount('12.34', currency: 'USD'), '12.34 USD');
      expect(formatApiAmount('12.34'), '12.34');
    });

    test('returns null for unusable input so the UI shows unavailable', () {
      expect(formatApiAmount(null), isNull);
      expect(formatApiAmount(''), isNull);
      expect(formatApiAmount('not-a-number'), isNull);
      // Already-formatted input is rejected rather than double-formatted.
      expect(formatApiAmount('1,000'), isNull);
    });
  });

  group('ProfileImageSignedUrlData', () {
    test('accepts an HTTPS URL with a positive expiry', () {
      final data = ProfileImageSignedUrlData.fromJson({
        'imageUrl': 'https://example.test/image.jpg?sig=abc',
        'expiresInSeconds': 900,
      });
      expect(data.imageUrl, 'https://example.test/image.jpg?sig=abc');
      expect(data.expiresInSeconds, 900);
      expect(data.isExpired, isFalse);
    });

    test('rejects a non-HTTPS or malformed URL', () {
      expect(
        () => ProfileImageSignedUrlData.fromJson({
          'imageUrl': 'http://example.test/image.jpg',
          'expiresInSeconds': 900,
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ProfileImageSignedUrlData.fromJson({
          'imageUrl': 'not a url',
          'expiresInSeconds': 900,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a non-positive expiry', () {
      expect(
        () => ProfileImageSignedUrlData.fromJson({
          'imageUrl': 'https://example.test/image.jpg',
          'expiresInSeconds': 0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('treats a URL issued past its lifetime as expired', () {
      final stale = ProfileImageSignedUrlData(
        imageUrl: 'https://example.test/image.jpg',
        expiresInSeconds: 60,
        fetchedAtUtc: DateTime.now().toUtc().subtract(
          const Duration(minutes: 5),
        ),
      );
      expect(stale.isExpired, isTrue);
    });
  });

  group('UserHomeData', () {
    test('parses documented wallet and virtual-account fields', () {
      final home = UserHomeData.fromJson({
        'user': {'anything': 1},
        'verification': {'other': true},
        'flexWallet': {
          'walletId': 'w1',
          'currency': 'NGN',
          'availableBalance': '1000.00',
          'ledgerBalance': '1200.00',
          'status': 'active',
        },
        'dedicatedVirtualAccount': {
          'status': 'available',
          'accountNumber': '0123456789',
          'bankName': 'Test Bank',
        },
        'savingsProducts': [
          {'id': 'p1'},
        ],
      });

      expect(home.flexWallet!.availableBalance, '1000.00');
      expect(home.flexWallet!.isActive, isTrue);
      expect(
        home.dedicatedVirtualAccount!.status,
        DedicatedVirtualAccountStatus.available,
      );
      expect(home.dedicatedVirtualAccount!.canDisplayDetails, isTrue);
      expect(home.savingsProducts, hasLength(1));
    });

    test(
      'preserves an unknown virtual-account status without acting on it',
      () {
        final home = UserHomeData.fromJson({
          'user': <String, Object?>{},
          'verification': <String, Object?>{},
          'dedicatedVirtualAccount': {'status': 'something_new'},
          'savingsProducts': <Object?>[],
        });

        final account = home.dedicatedVirtualAccount!;
        expect(account.status, DedicatedVirtualAccountStatus.unknown);
        expect(account.rawStatus, 'something_new');
        // An unknown status must never expose account details.
        expect(account.canDisplayDetails, isFalse);
      },
    );

    test(
      'does not treat an available account with no number as displayable',
      () {
        final home = UserHomeData.fromJson({
          'user': <String, Object?>{},
          'verification': <String, Object?>{},
          'dedicatedVirtualAccount': {'status': 'available'},
          'savingsProducts': <Object?>[],
        });
        expect(home.dedicatedVirtualAccount!.canDisplayDetails, isFalse);
      },
    );

    test('a non-active wallet status is not reported as active', () {
      final home = UserHomeData.fromJson({
        'user': <String, Object?>{},
        'verification': <String, Object?>{},
        'flexWallet': {'status': 'frozen'},
        'savingsProducts': <Object?>[],
      });
      expect(home.flexWallet!.isActive, isFalse);
    });

    test('keeps undocumented sections as immutable raw maps', () {
      final home = UserHomeData.fromJson({
        'user': {'nested': 'value'},
        'verification': <String, Object?>{},
        'savingsProducts': <Object?>[],
      });
      expect(home.user['nested'], 'value');
      expect(() => home.user['x'] = 1, throwsUnsupportedError);
    });
  });

  group('KYC identity', () {
    test('accepts exactly 11 digits', () {
      expect(isValidIdentityNumber('12345678901'), isTrue);
      expect(isValidIdentityNumber('  12345678901  '), isTrue);
    });

    test('rejects wrong length or non-digits', () {
      expect(isValidIdentityNumber('1234567890'), isFalse);
      expect(isValidIdentityNumber('123456789012'), isFalse);
      expect(isValidIdentityNumber('1234567890a'), isFalse);
      expect(isValidIdentityNumber('123-456-7890'), isFalse);
      expect(isValidIdentityNumber(''), isFalse);
    });

    test('request emits only the documented wire values', () {
      expect(
        const IdentityVerificationRequest(
          identityType: IdentityType.bvn,
          identityNumber: '12345678901',
        ).toJson(),
        {'identityType': 'bvn', 'identityNumber': '12345678901'},
      );
      expect(
        const IdentityVerificationRequest(
          identityType: IdentityType.nin,
          identityNumber: '12345678901',
        ).toJson()['identityType'],
        'nin',
      );
    });

    test('government-ID document types emit the backend wire values', () {
      expect(GovernmentIdDocumentType.values.map((t) => t.wireValue).toList(), [
        'voter_id',
        'drivers_license',
        'international_passport',
        'nin_slip',
      ]);
    });

    test('government-ID request defaults country and omits a blank number', () {
      expect(
        const GovernmentIdVerificationRequest(
          documentType: GovernmentIdDocumentType.driversLicense,
        ).toJson(),
        {'documentType': 'drivers_license', 'country': 'NG'},
      );
      expect(
        const GovernmentIdVerificationRequest(
          documentType: GovernmentIdDocumentType.voterId,
          documentNumber: '   ',
        ).toJson().containsKey('documentNumber'),
        isFalse,
      );
      expect(
        const GovernmentIdVerificationRequest(
          documentType: GovernmentIdDocumentType.ninSlip,
          documentNumber: ' ABC123 ',
        ).toJson()['documentNumber'],
        'ABC123',
      );
    });

    test('initiation reads the job type the backend chose', () {
      expect(
        KycInitiationData.fromJson({
          'verificationId': 'v-1',
          'sdkJobType': 'enhancedKyc',
        }).sdkJobType,
        'enhancedKyc',
      );
      // `jobType` is the documented alias for the same value.
      expect(
        KycInitiationData.fromJson({
          'verificationId': 'v-1',
          'jobType': 'enhancedDocumentVerification',
        }).sdkJobType,
        'enhancedDocumentVerification',
      );
    });

    test('initiation parses server-issued identifiers', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'v-123',
        'provider': 'smile_id',
        'environment': 'sandbox',
        'identityLast4': '8901',
        'smileJobId': 'job-1',
        'partnerParams': {'k': 'v'},
      });
      expect(data.verificationId, 'v-123');
      expect(data.smileJobId, 'job-1');
      expect(data.identityLast4, '8901');
      expect(() => data.partnerParams['x'] = 1, throwsUnsupportedError);
    });

    test('initiation moves the flow to awaiting, never to verified', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'v-123',
        'identityLast4': '8901',
      });
      final flow = const KycFlowData().fromInitiation(
        data,
        KycFlowStage.awaitingProvider,
      );
      expect(flow.stage, KycFlowStage.awaitingProvider);
      expect(flow.verificationId, 'v-123');
      // There is no verified stage a client can assign to itself.
      expect(KycFlowStage.values, isNot(contains('verified')));
    });

    test(
      'verificationId survives a stage change so a retry is not orphaned',
      () {
        final flow = const KycFlowData(
          stage: KycFlowStage.awaitingProvider,
          verificationId: 'v-123',
        ).copyWith(stage: KycFlowStage.failed);
        expect(flow.verificationId, 'v-123');
      },
    );
    test('identity initiation reads identityLast4', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'verification-1',
        'identityLast4': '8901',
      });
      expect(data.identityLast4, '8901');
    });

    test('government initiation preserves country and masked number', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'verification-2',
        'country': 'NG',
        'documentType': 'drivers_license',
        'documentNumberLast4': '3456',
      });
      expect(data.country, 'NG');
      expect(data.documentNumberLast4, '3456');
    });
  });

  group('Utility bill upload', () {
    test('maps only the accepted extensions to a content type', () {
      expect(contentTypeForExtension('pdf'), 'application/pdf');
      expect(contentTypeForExtension('PDF'), 'application/pdf');
      expect(contentTypeForExtension('jpg'), 'image/jpeg');
      expect(contentTypeForExtension('jpeg'), 'image/jpeg');
      expect(contentTypeForExtension('png'), 'image/png');
      expect(contentTypeForExtension('docx'), isNull);
      expect(contentTypeForExtension(null), isNull);
      // Every mapped type must be one the API accepts.
      for (final extension in kUtilityBillExtensions) {
        expect(
          kUtilityBillContentTypes,
          contains(contentTypeForExtension(extension)),
        );
      }
    });

    test('meter type emits the exact documented casing', () {
      expect(UtilityType.prePaid.wireValue, 'PrePaid');
      expect(UtilityType.postPaid.wireValue, 'PostPaid');
    });

    test('initiation request omits blank optional fields', () {
      final json = const UtilityBillInitiationRequest(
        residentialAddress: '1 Example Street',
        contentType: 'application/pdf',
        residentialState: '   ',
        residentialLga: '',
        utilityNumber: 'M-1',
        utilityType: UtilityType.prePaid,
      ).toJson();

      expect(json['residentialAddress'], '1 Example Street');
      expect(json['contentType'], 'application/pdf');
      expect(json['utilityType'], 'PrePaid');
      expect(json['utilityNumber'], 'M-1');
      expect(json.containsKey('residentialState'), isFalse);
      expect(json.containsKey('residentialLga'), isFalse);
    });

    test('upload target requires an HTTPS URL', () {
      expect(
        () => UtilityBillUploadTarget.fromJson({
          'verificationId': 'v-1',
          'uploadUrl': 'http://storage.test/key',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('always sends content type and server-side encryption headers', () {
      final target = UtilityBillUploadTarget.fromJson({
        'verificationId': 'v-1',
        'uploadUrl': 'https://storage.test/key?sig=abc',
        'expiresInSeconds': 600,
      });
      final headers = target.headersFor('image/png');
      expect(headers['Content-Type'], 'image/png');
      expect(headers['x-amz-server-side-encryption'], 'AES256');
    });

    test('API-supplied headers win over the defaults', () {
      final target = UtilityBillUploadTarget.fromJson({
        'verificationId': 'v-1',
        'uploadUrl': 'https://storage.test/key',
        'requiredHeaders': {
          'Content-Type': 'application/pdf',
          'x-amz-server-side-encryption': 'aws:kms',
        },
      });
      final headers = target.headersFor('image/png');
      expect(headers['Content-Type'], 'application/pdf');
      expect(headers['x-amz-server-side-encryption'], 'aws:kms');
    });

    test('dropping the upload target forces a fresh initiation', () {
      final flow = const KycFlowData(
        stage: KycFlowStage.uploading,
        verificationId: 'v-1',
      ).withoutUploadTarget();
      // A lapsed signed link must never be reused for a retry.
      expect(flow.verificationId, isNull);
      expect(flow.uploadCompleted, isFalse);
    });

    test('a selected bill reports its own size', () {
      const bill = SelectedUtilityBill(
        fileName: 'bill.pdf',
        contentType: 'application/pdf',
        bytes: [1, 2, 3],
      );
      expect(bill.sizeInBytes, 3);
      expect(kUtilityBillMaxBytes, 10485760);
    });
    test('utility request emits the published address keys', () {
      final json = UtilityBillInitiationRequest(
        residentialAddress: '1 Broad Street',
        residentialState: 'Lagos',
        residentialLga: 'Lagos Island',
        billIssuedAt: DateTime.utc(2026, 8, 31),
        contentType: 'application/pdf',
      ).toJson();
      expect(json['residentialState'], 'Lagos');
      expect(json['residentialLga'], 'Lagos Island');
      expect(json['billIssuedAt'], '2026-08-31T00:00:00.000Z');
      expect(json.containsKey('state'), isFalse);
      expect(json.containsKey('lga'), isFalse);
      expect(json.containsKey('billIssueDate'), isFalse);
    });

    test('utility completion parses verification and pending status', () {
      final data = UtilityBillCompletionData.fromJson({
        'verificationId': 'verification-3',
        'status': 'pending_review',
      });
      expect(data.verificationId, 'verification-3');
      expect(data.status, 'pending_review');
    });
  });
}
