import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

Map<String, Object?> _immutableMap(Object? value) => value is Map
    ? Map<String, Object?>.unmodifiable(Map<String, Object?>.from(value))
    : const <String, Object?>{};

/// Provisioning state of the user's dedicated virtual account.
///
/// [unknown] preserves the raw wire value so an undocumented status can be
/// displayed and logged without ever enabling a financial action.
enum DedicatedVirtualAccountStatus {
  available('available'),
  pending('pending'),
  failed('failed'),
  notRequested('not_requested'),
  unknown('unknown');

  const DedicatedVirtualAccountStatus(this.wireValue);
  final String wireValue;

  static DedicatedVirtualAccountStatus fromWire(Object? value) =>
      switch (value) {
        'available' => available,
        'pending' => pending,
        'failed' => failed,
        'not_requested' => notRequested,
        _ => unknown,
      };
}

/// Flex wallet balances and status.
///
/// Balances stay [String] at the transport boundary. They are API-authoritative
/// decimal strings and must never be parsed to `double` or used for arithmetic
/// in the client.
class FlexWalletData extends Equatable {
  const FlexWalletData({
    this.walletId,
    this.walletType,
    this.currency,
    this.availableBalance,
    this.ledgerBalance,
    this.status,
  });

  factory FlexWalletData.fromJson(Object? value) {
    final json = _map(value);
    return FlexWalletData(
      walletId: json['walletId'] as String?,
      walletType: json['walletType'] as String?,
      currency: json['currency'] as String?,
      availableBalance: json['availableBalance'] as String?,
      ledgerBalance: json['ledgerBalance'] as String?,
      status: json['status'] as String?,
    );
  }

  final String? walletId;
  final String? walletType;
  final String? currency;
  final String? availableBalance;
  final String? ledgerBalance;
  final String? status;

  /// True only for an explicitly active wallet. An unknown or absent status is
  /// never treated as active.
  bool get isActive => status?.toLowerCase() == 'active';

  @override
  List<Object?> get props => [
    walletId,
    walletType,
    currency,
    availableBalance,
    ledgerBalance,
    status,
  ];
}

/// Dedicated virtual account used to fund the wallet by bank transfer.
class DedicatedVirtualAccountData extends Equatable {
  const DedicatedVirtualAccountData({
    required this.status,
    required this.rawStatus,
    this.accountName,
    this.accountNumber,
    this.bankName,
    this.bankSlug,
    this.provider,
    this.failureReason,
  });

  factory DedicatedVirtualAccountData.fromJson(Object? value) {
    final json = _map(value);
    return DedicatedVirtualAccountData(
      status: DedicatedVirtualAccountStatus.fromWire(json['status']),
      rawStatus: json['status'] as String?,
      accountName: json['accountName'] as String?,
      accountNumber: json['accountNumber'] as String?,
      bankName: json['bankName'] as String?,
      bankSlug: json['bankSlug'] as String?,
      provider: json['provider'] as String?,
      failureReason: json['failureReason'] as String?,
    );
  }

  final DedicatedVirtualAccountStatus status;

  /// Raw wire value, retained so an unknown status can be logged verbatim.
  final String? rawStatus;
  final String? accountName;
  final String? accountNumber;
  final String? bankName;
  final String? bankSlug;
  final String? provider;
  final String? failureReason;

  /// Account details may only be shown when the provider reports the account
  /// as available and both bank and account number were returned.
  bool get canDisplayDetails =>
      status == DedicatedVirtualAccountStatus.available &&
      (accountNumber?.trim().isNotEmpty ?? false) &&
      (bankName?.trim().isNotEmpty ?? false);

  @override
  List<Object?> get props => [
    status,
    rawStatus,
    accountName,
    accountNumber,
    bankName,
    bankSlug,
    provider,
    failureReason,
  ];
}

/// Aggregate payload behind `GET /users/me/home`.
///
/// `user`, `verification`, and `savingsProducts` are declared as free-form
/// objects in the current OpenAPI document, so they are preserved as immutable
/// raw maps. Savings uses a separate defensive catalogue adapter for names
/// and supported navigation; financial terms remain undisplayed.
class UserHomeData extends Equatable {
  const UserHomeData({
    required this.user,
    required this.verification,
    this.flexWallet,
    this.dedicatedVirtualAccount,
    required this.savingsProducts,
  });

  factory UserHomeData.fromJson(Object? value) {
    final json = _map(value);
    final savings = json['savingsProducts'];
    return UserHomeData(
      user: _immutableMap(json['user']),
      verification: _immutableMap(json['verification']),
      flexWallet: json['flexWallet'] == null
          ? null
          : FlexWalletData.fromJson(json['flexWallet']),
      dedicatedVirtualAccount: json['dedicatedVirtualAccount'] == null
          ? null
          : DedicatedVirtualAccountData.fromJson(
              json['dedicatedVirtualAccount'],
            ),
      savingsProducts: List<Map<String, Object?>>.unmodifiable(
        savings is List ? savings.map(_immutableMap) : const [],
      ),
    );
  }

  final Map<String, Object?> user;
  final Map<String, Object?> verification;
  final FlexWalletData? flexWallet;
  final DedicatedVirtualAccountData? dedicatedVirtualAccount;
  final List<Map<String, Object?>> savingsProducts;

  @override
  List<Object?> get props => [
    user,
    verification,
    flexWallet,
    dedicatedVirtualAccount,
    savingsProducts,
  ];
}
