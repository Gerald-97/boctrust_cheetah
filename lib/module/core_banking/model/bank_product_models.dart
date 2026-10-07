import 'package:equatable/equatable.dart';

/// One product from the Core catalogue (`GET /bank-products`).
///
/// `interestRate` and `tenure` are published as JSON numbers from BankOne's
/// live product data. They are shown as product facts only and are never used
/// in a calculation; either is null when BankOne's lookup failed. `loanCycle`
/// does not apply to savings and is ignored.
class CoreBankProduct extends Equatable {
  const CoreBankProduct({
    required this.code,
    required this.name,
    this.description,
    this.interestRate,
    this.tenureDays,
    this.discriminator,
  });

  final String code;
  final String name;
  final String? description;

  /// Percent, as published.
  final num? interestRate;

  /// In days, as published.
  final int? tenureDays;

  /// BankOne's product family, such as `FixedDeposit` or `SavingsorCurrent`.
  final String? discriminator;

  bool get isFixedDeposit =>
      discriminator?.toLowerCase().replaceAll(RegExp('[^a-z]'), '') ==
      'fixeddeposit';

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static CoreBankProduct? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = _text(json['code']);
    final name = _text(json['name']);
    if (code == null || name == null) return null;
    final rate = json['interestRate'];
    final tenure = json['tenure'];
    return CoreBankProduct(
      code: code,
      name: name,
      description: _text(json['description']),
      // Staging sends 0 when BankOne has no rate; never show "0% p.a.".
      interestRate: rate is num && rate.isFinite && rate > 0 ? rate : null,
      tenureDays: tenure is num && tenure.isFinite && tenure > 0
          ? tenure.round()
          : null,
      discriminator: _text(json['productDiscriminator']),
    );
  }

  /// Valid products in server order; the first of any duplicated code wins.
  static List<CoreBankProduct> listFromJson(Object? json) {
    if (json is! List) throw const FormatException('Missing bank products.');
    final seen = <String>{};
    return List.unmodifiable(
      json
          .map(tryParse)
          .whereType<CoreBankProduct>()
          .where((product) => seen.add(product.code)),
    );
  }

  @override
  List<Object?> get props => [
    code,
    name,
    description,
    interestRate,
    tenureDays,
    discriminator,
  ];
}
