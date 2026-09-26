import 'package:equatable/equatable.dart';

enum TransactionDirection { credit, debit, internal }

enum TransactionStatus { pending, successful, failed, reversed }

TransactionStatus? _statusFrom(Object? raw) => switch (raw) {
  'pending' || 'processing' => TransactionStatus.pending,
  'successful' || 'success' || 'completed' => TransactionStatus.successful,
  'failed' => TransactionStatus.failed,
  'reversed' => TransactionStatus.reversed,
  _ => null,
};

String? _text(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

/// Proof of a completed transaction. It can only be built from a server
/// response that reports success, so no screen can manufacture a receipt.
class TransactionReceipt extends Equatable {
  const TransactionReceipt._({
    required this.reference,
    required this.amount,
    required this.title,
    required this.completedAt,
    required this.details,
  });

  /// Throws [FormatException] unless [json] is a successful transaction with
  /// a reference and an amount.
  factory TransactionReceipt.fromJson(Map<String, Object?> json) {
    final status = _statusFrom(json['status']);
    final reference = _text(json['reference']);
    final amount = _text(json['amount']);
    final completedAt = DateTime.tryParse('${json['completedAt']}');
    if (status != TransactionStatus.successful ||
        reference == null ||
        amount == null ||
        completedAt == null) {
      throw const FormatException('Not a completed transaction receipt.');
    }
    final rawDetails = json['details'];
    return TransactionReceipt._(
      reference: reference,
      amount: amount,
      title: _text(json['title']) ?? 'Transaction successful',
      completedAt: completedAt,
      details: [
        if (rawDetails is List)
          for (final row in rawDetails)
            if (row is Map &&
                _text(row['label']) != null &&
                _text(row['value']) != null)
              (label: _text(row['label'])!, value: _text(row['value'])!),
      ],
    );
  }

  final String reference;

  /// Server-formatted amount.
  final String amount;
  final String title;
  final DateTime completedAt;

  /// Server-supplied label/value rows (to, method, fee…).
  final List<({String label, String value})> details;

  @override
  List<Object?> get props => [reference, amount, title, completedAt, details];
}

/// One row of transaction history, as the server reports it.
class TransactionRecord extends Equatable {
  const TransactionRecord({
    required this.id,
    required this.title,
    required this.direction,
    required this.status,
    required this.amount,
    required this.occurredAt,
    this.receipt,
  });

  final String id;
  final String title;
  final TransactionDirection direction;
  final TransactionStatus status;

  /// Server-formatted, unsigned amount; the sign follows [direction].
  final String amount;
  final DateTime occurredAt;

  /// Present only when the server returned a completed receipt.
  final TransactionReceipt? receipt;

  @override
  List<Object?> get props => [
    id,
    title,
    direction,
    status,
    amount,
    occurredAt,
    receipt,
  ];
}

/// A transfer the customer has reviewed and authorised with their PIN.
class TransferRequest {
  const TransferRequest({
    required this.accountNumber,
    required this.bankName,
    required this.amount,
    required this.pin,
    this.narration,
  });

  final String accountNumber;
  final String bankName;

  /// Naira amount as typed, validated as a positive number.
  final String amount;
  final String? narration;

  /// Transaction PIN; never logged or shown.
  final String pin;

  @override
  String toString() =>
      'TransferRequest(to: $bankName ••••'
      '${accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : ''}'
      ', amount: $amount)';
}
