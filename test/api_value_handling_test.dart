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

    test('government-ID request omits an absent document number', () {
      expect(
        const GovernmentIdVerificationRequest(
          documentType: 'voter_id',
        ).toJson(),
        {'documentType': 'voter_id'},
      );
      expect(
        const GovernmentIdVerificationRequest(
          documentType: 'voter_id',
          documentNumber: '',
        ).toJson().containsKey('documentNumber'),
        isFalse,
      );
    });

    test('initiation parses server-issued identifiers', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'v-123',
        'provider': 'smile_id',
        'environment': 'sandbox',
        'identityLastFour': '8901',
        'smileJobId': 'job-1',
        'partnerParams': {'k': 'v'},
      });
      expect(data.verificationId, 'v-123');
      expect(data.smileJobId, 'job-1');
      expect(data.identityLastFour, '8901');
      expect(() => data.partnerParams['x'] = 1, throwsUnsupportedError);
    });

    test('initiation moves the flow to awaiting, never to verified', () {
      final data = KycInitiationData.fromJson({
        'verificationId': 'v-123',
        'identityLastFour': '8901',
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
  });
}
