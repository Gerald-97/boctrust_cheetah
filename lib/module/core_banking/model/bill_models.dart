import 'package:equatable/equatable.dart';

import 'core_json.dart';

/// A bill category from `GET /me/bills/billers/categories`.
class BillerCategory extends Equatable {
  const BillerCategory({
    required this.id,
    required this.name,
    this.description,
    this.isAirtime = false,
  });

  final String id;
  final String name;
  final String? description;
  final bool isAirtime;

  /// Data plans: no flag is published, so the category name decides.
  bool get isData => name.toLowerCase().contains('data');

  static List<BillerCategory> listFromJson(Object? json) => List.unmodifiable([
    for (final row in coreRows(json, const ['categories', 'items', 'data']))
      if (row is Map)
        if ((coreId(row['id']), coreText(row['name'])) case (
          final String id,
          final String name,
        ))
          BillerCategory(
            id: id,
            name: name,
            description: coreText(row['description']),
            isAirtime: row['isAirtime'] == true,
          ),
  ]);

  @override
  List<Object?> get props => [id, name, description, isAirtime];
}

/// A biller from `GET /me/bills/billers`. Only active billers are kept.
class Biller extends Equatable {
  const Biller({
    required this.id,
    required this.categoryId,
    required this.name,
    this.customerFieldLabel = 'Customer ID',
  });

  /// Sent as text even though the list publishes a number.
  final String id;
  final String categoryId;
  final String name;

  /// What the biller calls the customer's identifier (e.g. "SmartCard No").
  final String customerFieldLabel;

  static List<Biller> listFromJson(Object? json) => List.unmodifiable([
    for (final row in coreRows(json, const ['billers', 'items', 'data']))
      if (row is Map && row['isActive'] != false)
        if ((
              coreId(row['billerId']) ?? coreId(row['id']),
              coreId(row['billerCategoryId']) ?? coreId(row['categoryId']),
              coreText(row['name']),
            )
            case (final String id, final String categoryId, final String name))
          Biller(
            id: id,
            categoryId: categoryId,
            name: name,
            customerFieldLabel:
                coreText(row['customerField1']) ?? 'Customer ID',
          ),
  ]);

  @override
  List<Object?> get props => [id, categoryId, name, customerFieldLabel];
}

final _naira = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$');

/// A two-decimal Naira string, or null when [value] is not an exact positive
/// amount with at most two decimals. Floats such as `1.005` are refused
/// rather than rounded.
String? _nairaAmount(Object? value) {
  final text = switch (value) {
    final int number => '$number',
    final double number => number.toString().replaceFirst(RegExp(r'\.0$'), ''),
    final String text => text.trim(),
    _ => null,
  };
  final match = _naira.firstMatch(text ?? '');
  if (match == null) return null;
  final whole = BigInt.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  if (whole == BigInt.zero && fraction == '00') return null;
  return '$whole.$fraction';
}

/// A plan or package from `GET /me/bills/payment-items`.
class PaymentItem extends Equatable {
  const PaymentItem({
    required this.id,
    required this.billerId,
    required this.name,
    this.code,
    this.amountNaira,
  });

  final String id;
  final String billerId;
  final String name;
  final String? code;

  /// The fixed price, or null when the customer enters the amount (or the
  /// published amount is not an exact Naira value).
  final String? amountNaira;

  static List<PaymentItem> listFromJson(Object? json) => List.unmodifiable([
    for (final row in coreRows(json, const ['paymentItems', 'items', 'data']))
      if (row is Map)
        if ((
              coreId(row['id']) ?? coreId(row['paymentItemId']),
              coreId(row['billerId']),
              coreText(row['name']),
            )
            case (final String id, final String billerId, final String name))
          PaymentItem(
            id: id,
            billerId: billerId,
            name: name,
            code: coreId(row['code']),
            amountNaira: _nairaAmount(row['amount']),
          ),
  ]);

  @override
  List<Object?> get props => [id, billerId, name, code, amountNaira];
}

/// One bill, airtime or data payment, as reviewed. Core resolves names,
/// category and the customer's contact details itself.
class BillPaymentDraft extends Equatable {
  const BillPaymentDraft({
    required this.billerId,
    required this.paymentItemId,
    required this.customerId,
    required this.amountNaira,
  });

  final String billerId;
  final String paymentItemId;

  /// The customer's identifier with the biller (meter, smartcard, phone).
  final String customerId;

  /// Two-decimal Naira string; bills are not sent in Kobo.
  final String amountNaira;

  Map<String, Object?> toJson() => {
    'billerId': billerId,
    'paymentItemId': paymentItemId,
    'customerId': customerId,
    'amount': amountNaira,
  };

  @override
  List<Object?> get props => [billerId, paymentItemId, customerId, amountNaira];
}
