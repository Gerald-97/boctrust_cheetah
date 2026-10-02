import 'package:equatable/equatable.dart';

/// One product from the Core catalogue (`GET /bank-products`).
///
/// `interestRate`, `tenure` and `loanCycle` are published as JSON numbers, so
/// they are neither displayed nor used in calculations until they are
/// published as decimal strings.
class CoreBankProduct extends Equatable {
  const CoreBankProduct({
    required this.code,
    required this.name,
    this.description,
  });

  final String code;
  final String name;
  final String? description;

  static CoreBankProduct? tryParse(Object? json) {
    if (json is! Map) return null;
    final code = json['code'];
    final name = json['name'];
    if (code is! String || code.trim().isEmpty) return null;
    if (name is! String || name.trim().isEmpty) return null;
    final description = json['description'];
    return CoreBankProduct(
      code: code.trim(),
      name: name.trim(),
      description: description is String && description.trim().isNotEmpty
          ? description.trim()
          : null,
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
  List<Object?> get props => [code, name, description];
}
