import 'package:equatable/equatable.dart';

/// The bounded display contract for the otherwise free-form Home catalogue.
/// Financial terms are intentionally excluded until their API units and
/// semantics have a documented contract.
class SavingsProductData extends Equatable {
  const SavingsProductData({
    required this.code,
    required this.name,
    this.walletType,
    this.productKind,
  });

  final String code;
  final String name;
  final String? walletType;
  final String? productKind;

  bool get canOpenFlex => code == 'bocFlex' && walletType == 'bocFlex';

  /// Keeps server order, collapses matching display records, and omits every
  /// occurrence of a code whose valid records disagree about its identity.
  static List<SavingsProductData> parseCatalogue(
    List<Map<String, Object?>> rows,
  ) {
    final products = <String, SavingsProductData>{};
    final conflicts = <String>{};
    for (final row in rows) {
      final code = _nonblankString(row['code']);
      final name = _nonblankString(row['name']);
      if (code == null || name == null || conflicts.contains(code)) continue;

      final product = SavingsProductData(
        code: code,
        name: name.trim(),
        walletType: _nonblankString(row['walletType']),
        productKind: _nonblankString(row['productKind']),
      );
      final previous = products[code];
      if (previous != null && previous != product) {
        products.remove(code);
        conflicts.add(code);
      } else {
        products[code] = product;
      }
    }
    return List<SavingsProductData>.unmodifiable(products.values);
  }

  // Preserve identifiers exactly: whitespace must not turn an unknown server
  // identifier into a supported navigation target.
  static String? _nonblankString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  @override
  List<Object?> get props => [code, name, walletType, productKind];
}
