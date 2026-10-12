import 'package:equatable/equatable.dart';

import 'core_json.dart';
import 'core_money.dart';

/// A destination bank from `GET /me/interbank/banks`.
class CommercialBank extends Equatable {
  const CommercialBank({required this.code, required this.name});

  final String code;
  final String name;

  /// Whether this is BOCTRUST itself, matched by name. A BOCTRUST recipient
  /// is looked up with this code but paid through the intrabank routes.
  bool get isBoctrust => name.toLowerCase().contains('boctrust');

  /// The one BOCTRUST entry in [banks], or null when none or several match.
  static CommercialBank? boctrustIn(Iterable<CommercialBank> banks) {
    final matches = banks.where((bank) => bank.isBoctrust).toList();
    return matches.length == 1 ? matches.single : null;
  }

  /// Banks sorted by name; a row without a code or name is dropped, and a
  /// repeated code keeps its first row.
  static List<CommercialBank> listFromJson(Object? json) {
    final byCode = <String, CommercialBank>{};
    for (final row in coreRows(json, const ['banks', 'items', 'data'])) {
      if (row is! Map) continue;
      final code = coreId(row['code']) ?? coreId(row['bankCode']);
      final name = coreFirstText(row, const ['name', 'bankName']);
      if (code == null || name == null) continue;
      byCode.putIfAbsent(code, () => CommercialBank(code: code, name: name));
    }
    return List.unmodifiable(
      byCode.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  @override
  List<Object?> get props => [code, name];
}

/// A resolved account name. Sensitive fields the Core reply may carry are
/// dropped here and never stored.
class NameEnquiryResult extends Equatable {
  const NameEnquiryResult(this.name);

  factory NameEnquiryResult.fromJson(Object? json) {
    final name = json is Map
        ? coreFirstText(json, const ['name', 'accountName'])
        : null;
    if (name == null) throw const FormatException('Missing account name.');
    return NameEnquiryResult(name);
  }

  final String name;

  @override
  List<Object?> get props => [name];
}

/// A receiving account whose name Core confirmed, for one bank and number.
class ResolvedRecipient extends Equatable {
  const ResolvedRecipient({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.name,
  });

  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String name;

  @override
  List<Object?> get props => [bankCode, bankName, accountNumber, name];
}

/// One transfer to another bank, as reviewed.
class InterbankTransferDraft extends Equatable {
  const InterbankTransferDraft({
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.amountKobo,
    this.narration,
  });

  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;

  /// Integer Kobo string from `parseNairaToKobo`.
  final String amountKobo;
  final String? narration;

  /// The staged interbank initiate body; Core requires [amountKobo] as a
  /// digit-only Kobo string.
  Map<String, Object?> toJson() {
    final note = narration?.trim() ?? '';
    return {
      'receiverBankCode': bankCode,
      'receiverAccountNumber': accountNumber,
      'amount': koboToNaira(amountKobo),
      if (note.isNotEmpty) 'narration': note,
    };
  }

  @override
  List<Object?> get props => [
    bankCode,
    bankName,
    accountNumber,
    accountName,
    amountKobo,
    narration,
  ];
}

enum InterbankTransferState { pending, completed, failed, unknown }

/// Core's last known outcome of an interbank transfer (not a live re-query).
class InterbankTransferStatus extends Equatable {
  const InterbankTransferStatus({
    required this.state,
    this.reference,
    this.message,
  });

  factory InterbankTransferStatus.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('Invalid transfer status.');
    final status = coreText(json['status']);
    return InterbankTransferStatus(
      state:
          InterbankTransferState.values
              .where((s) => s != InterbankTransferState.unknown)
              .where((s) => s.name == status)
              .firstOrNull ??
          InterbankTransferState.unknown,
      reference: coreText(json['reference']),
      message: coreText(json['message']),
    );
  }

  final InterbankTransferState state;
  final String? reference;
  final String? message;

  @override
  List<Object?> get props => [state, reference, message];
}
