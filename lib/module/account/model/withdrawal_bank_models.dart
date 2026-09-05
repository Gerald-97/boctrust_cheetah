import 'package:equatable/equatable.dart';

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);

String? _text(Object? value) {
  final result = value is String ? value.trim() : null;
  return (result == null || result.isEmpty) ? null : result;
}

String _requiredText(Map<String, Object?> json, String key) {
  final result = _text(json[key]);
  if (result == null) {
    throw FormatException('Missing $key in withdrawal bank payload.');
  }
  return result;
}

/// Exactly ten digits, the only account-number shape the API accepts.
final _tenDigits = RegExp(r'^\d{10}$');

String _validAccountNumber(String value) {
  final trimmed = value.trim();
  if (!_tenDigits.hasMatch(trimmed)) {
    throw const FormatException('Enter the ten digits of your account number.');
  }
  return trimmed;
}

String _validRequired(String value, String field) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw FormatException('Select a $field.');
  return trimmed;
}

/// One bank from the supported catalogue.
class BankData extends Equatable {
  const BankData({
    required this.name,
    required this.code,
    this.slug,
    this.country,
    this.currency,
  });

  factory BankData.fromJson(Object? value) {
    final json = _map(value);
    return BankData(
      name: _requiredText(json, 'name'),
      code: _requiredText(json, 'code'),
      slug: _text(json['slug']),
      country: _text(json['country']),
      currency: _text(json['currency']),
    );
  }

  final String name;
  final String code;
  final String? slug;
  final String? country;
  final String? currency;

  @override
  List<Object?> get props => [name, code, slug, country, currency];
}

class BankCatalogueData extends Equatable {
  const BankCatalogueData({required this.banks});

  factory BankCatalogueData.fromJson(Object? value) {
    final json = _map(value);
    final raw = json['banks'];
    return BankCatalogueData(
      banks: List<BankData>.unmodifiable(
        raw is List
            ? raw.map(BankData.fromJson)
            : const Iterable<BankData>.empty(),
      ),
    );
  }

  final List<BankData> banks;

  @override
  List<Object?> get props => [banks];
}

/// A withdrawal destination the server has accepted and stored.
class WithdrawalBankAccount extends Equatable {
  const WithdrawalBankAccount({
    required this.bankAccountId,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.nameMatchScore,
    this.provider,
    this.createdAt,
  });

  factory WithdrawalBankAccount.fromJson(Object? value) {
    final json = _map(value);
    return WithdrawalBankAccount(
      bankAccountId: _requiredText(json, 'bankAccountId'),
      bankCode: _requiredText(json, 'bankCode'),
      bankName: _requiredText(json, 'bankName'),
      accountNumber: _requiredText(json, 'accountNumber'),
      accountName: _requiredText(json, 'accountName'),
      // Kept as a string: a decimal score must never become a double.
      nameMatchScore: _text(json['nameMatchScore']),
      provider: _text(json['provider']),
      createdAt: DateTime.tryParse(_text(json['createdAt']) ?? '')?.toUtc(),
    );
  }

  final String bankAccountId;
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? nameMatchScore;
  final String? provider;
  final DateTime? createdAt;

  /// Display form. The comparison is `<= 4` because at exactly four characters
  /// a `< 4` test would print the whole value behind decorative bullets; ten
  /// digits are validated on requests, never on a server response.
  String get maskedAccountNumber => accountNumber.length <= 4
      ? '••••'
      : '••••••${accountNumber.substring(accountNumber.length - 4)}';

  @override
  List<Object?> get props => [
    bankAccountId,
    bankCode,
    bankName,
    accountNumber,
    accountName,
    nameMatchScore,
    provider,
    createdAt,
  ];
}

class WithdrawalBankAccountListData extends Equatable {
  const WithdrawalBankAccountListData({
    required this.bankAccounts,
    required this.maxAllowed,
  });

  factory WithdrawalBankAccountListData.fromJson(Object? value) {
    final json = _map(value);
    final raw = json['bankAccounts'];
    final max = json['maxAllowed'];
    return WithdrawalBankAccountListData(
      bankAccounts: List<WithdrawalBankAccount>.unmodifiable(
        raw is List
            ? raw.map(WithdrawalBankAccount.fromJson)
            : const Iterable<WithdrawalBankAccount>.empty(),
      ),
      maxAllowed: max is num ? max.toInt() : null,
    );
  }

  final List<WithdrawalBankAccount> bankAccounts;

  /// The server's cap. Never hard-coded: the documented example is 2, but the
  /// returned value is the one that applies.
  final int? maxAllowed;

  /// False once the cap is reached. An unknown cap is not treated as unlimited.
  bool get canAddAnother {
    final max = maxAllowed;
    if (max == null) return false;
    return bankAccounts.length < max;
  }

  @override
  List<Object?> get props => [bankAccounts, maxAllowed];
}

/// Shared shape of the resolve and add requests.
///
/// Both validate before any request leaves the client, so a malformed account
/// number is a local error rather than a round trip.
class _WithdrawalBankAccountRequest {
  _WithdrawalBankAccountRequest({
    required String bankCode,
    required String bankName,
    required String accountNumber,
  }) : bankCode = _validRequired(bankCode, 'bank'),
       bankName = _validRequired(bankName, 'bank'),
       accountNumber = _validAccountNumber(accountNumber);

  final String bankCode;
  final String bankName;
  final String accountNumber;

  Map<String, Object?> toJson() => {
    'bankCode': bankCode,
    'bankName': bankName,
    'accountNumber': accountNumber,
  };
}

class ResolveWithdrawalBankAccountRequest
    extends _WithdrawalBankAccountRequest {
  ResolveWithdrawalBankAccountRequest({
    required super.bankCode,
    required super.bankName,
    required super.accountNumber,
  });
}

class AddWithdrawalBankAccountRequest extends _WithdrawalBankAccountRequest {
  AddWithdrawalBankAccountRequest({
    required super.bankCode,
    required super.bankName,
    required super.accountNumber,
  });
}

/// Name-match result for a bank account, before it is saved.
class ResolveWithdrawalBankAccountData extends Equatable {
  const ResolveWithdrawalBankAccountData({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.isNameMatch,
    this.nameMatchScore,
    this.minimumRequiredScore,
  });

  factory ResolveWithdrawalBankAccountData.fromJson(Object? value) {
    final json = _map(value);
    return ResolveWithdrawalBankAccountData(
      bankCode: _requiredText(json, 'bankCode'),
      bankName: _requiredText(json, 'bankName'),
      accountNumber: _requiredText(json, 'accountNumber'),
      accountName: _requiredText(json, 'accountName'),
      // Only an explicit true is a match; anything else is not authorizing.
      isNameMatch: json['isNameMatch'] == true,
      nameMatchScore: _text(json['nameMatchScore']),
      minimumRequiredScore: _text(json['minimumRequiredScore']),
    );
  }

  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final bool isNameMatch;

  /// Decimal strings, never parsed to double.
  final String? nameMatchScore;
  final String? minimumRequiredScore;

  /// Whether this resolution still describes the account the user has selected.
  bool matches({required String bankCode, required String accountNumber}) =>
      this.bankCode == bankCode && this.accountNumber == accountNumber;

  @override
  List<Object?> get props => [
    bankCode,
    bankName,
    accountNumber,
    accountName,
    isNameMatch,
    nameMatchScore,
    minimumRequiredScore,
  ];
}

class AddWithdrawalBankAccountData extends Equatable {
  const AddWithdrawalBankAccountData({
    required this.bankAccount,
    this.minimumRequiredScore,
  });

  factory AddWithdrawalBankAccountData.fromJson(Object? value) {
    final json = _map(value);
    // The saved account is either nested or returned at the top level.
    final nested = json['bankAccount'];
    return AddWithdrawalBankAccountData(
      bankAccount: WithdrawalBankAccount.fromJson(nested ?? json),
      minimumRequiredScore: _text(json['minimumRequiredScore']),
    );
  }

  final WithdrawalBankAccount bankAccount;
  final String? minimumRequiredScore;

  @override
  List<Object?> get props => [bankAccount, minimumRequiredScore];
}

class DeleteWithdrawalBankAccountData extends Equatable {
  const DeleteWithdrawalBankAccountData({
    required this.bankAccountId,
    required this.status,
  });

  factory DeleteWithdrawalBankAccountData.fromJson(Object? value) {
    final json = _map(value);
    return DeleteWithdrawalBankAccountData(
      bankAccountId: _requiredText(json, 'bankAccountId'),
      status: _requiredText(json, 'status'),
    );
  }

  final String bankAccountId;
  final String status;

  @override
  List<Object?> get props => [bankAccountId, status];
}
