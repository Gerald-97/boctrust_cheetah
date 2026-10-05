import 'package:equatable/equatable.dart';

import 'core_json.dart';

enum BeneficiaryType {
  bankAccount('bank_account'),
  electricity('electricity'),
  water('water'),
  cableTv('cable_tv'),
  internet('internet'),
  betting('betting');

  const BeneficiaryType(this.wireValue);
  final String wireValue;

  static BeneficiaryType? parse(Object? value) =>
      values.where((type) => type.wireValue == value).firstOrNull;
}

/// A saved bank account or biller customer from `GET /me/beneficiaries`.
class Beneficiary extends Equatable {
  const Beneficiary({
    required this.id,
    required this.type,
    required this.number,
    required this.name,
    this.nickname,
    this.bankCode,
    this.bankName,
    this.billerId,
    this.paymentItemId,
    this.paymentItemName,
  });

  final String id;

  /// Null for a type this build does not know; such rows are listed only.
  final BeneficiaryType? type;

  /// Account number, or the customer's identifier with the biller.
  final String number;

  /// Verified account name, or the biller's name.
  final String name;
  final String? nickname;
  final String? bankCode;
  final String? bankName;
  final String? billerId;
  final String? paymentItemId;
  final String? paymentItemName;

  String get maskedNumber => number.length <= 4
      ? number
      : '•••• ${number.substring(number.length - 4)}';

  static List<Beneficiary> listFromJson(Object? json) => List.unmodifiable([
    for (final row in coreRows(json, const ['beneficiaries', 'items', 'data']))
      ?tryParse(row),
  ]);

  static Beneficiary? tryParse(Object? row) {
    if (row is! Map) return null;
    final id = coreId(row['beneficiaryId']) ?? coreId(row['id']);
    final number = coreText(row['number']);
    final name = coreText(row['name']);
    if (id == null || number == null || name == null) return null;
    return Beneficiary(
      id: id,
      type: BeneficiaryType.parse(row['type']),
      number: number,
      name: name,
      nickname: coreText(row['nickname']),
      bankCode: coreId(row['bankCode']),
      bankName: coreText(row['bankName']),
      billerId: coreId(row['billerId']),
      paymentItemId: coreId(row['paymentItemId']),
      paymentItemName: coreText(row['paymentItemName']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    number,
    name,
    nickname,
    bankCode,
    bankName,
    billerId,
    paymentItemId,
    paymentItemName,
  ];
}

Map<String, Object?> _withNickname(Map<String, Object?> body, String? nick) {
  final text = nick?.trim() ?? '';
  return {...body, if (text.isNotEmpty) 'nickname': text};
}

/// `POST /me/beneficiaries` body for a bank account.
Map<String, Object?> bankBeneficiaryRequest({
  required String bankCode,
  required String number,
  String? nickname,
}) => _withNickname({
  'type': BeneficiaryType.bankAccount.wireValue,
  'bankCode': bankCode,
  'number': number,
}, nickname);

/// `POST /me/beneficiaries` body for a biller customer.
Map<String, Object?> billBeneficiaryRequest({
  required BeneficiaryType type,
  required String billerId,
  required String billerName,
  required String categoryId,
  required String categoryName,
  required String paymentItemId,
  required String paymentItemName,
  required String number,
  String? nickname,
}) => _withNickname({
  'type': type.wireValue,
  'billerId': billerId,
  'name': billerName,
  'billerCategoryId': categoryId,
  'billerCategoryName': categoryName,
  'paymentItemId': paymentItemId,
  'paymentItemName': paymentItemName,
  'number': number,
}, nickname);
