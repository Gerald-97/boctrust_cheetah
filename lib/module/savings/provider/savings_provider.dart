import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/provider/home_provider.dart';
import '../model/savings_product_data.dart';

/// Derives the catalogue from the shared Home aggregate without a request.
final savingsProductsProvider = Provider<List<SavingsProductData>>((ref) {
  final home = ref.watch(userHomeProvider);
  return SavingsProductData.parseCatalogue(
    home.data?.savingsProducts ?? const [],
  );
});
