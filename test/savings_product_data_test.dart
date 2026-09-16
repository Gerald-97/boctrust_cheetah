import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/home/service/home_service.dart';
import 'package:boctrust_savings_loan/module/savings/model/savings_product_data.dart';
import 'package:boctrust_savings_loan/module/savings/provider/savings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'support/savings_fixtures.dart';

const _flex = <String, Object?>{
  'code': 'bocFlex',
  'name': 'BOC Flex',
  'walletType': 'bocFlex',
  'productKind': 'flexible',
};

class _HomeService implements HomeService {
  int calls = 0;
  final List<NotifierState<UserHomeData>> responses;
  _HomeService(this.responses);

  @override
  Future<NotifierState<UserHomeData>> getOwnHome() async => responses[calls++];
}

void main() {
  test('catalogue skips missing, blank and non-string identities', () {
    final products = SavingsProductData.parseCatalogue([
      {},
      {'code': 'bocFlex'},
      {'code': 1, 'name': 'Invalid'},
      {'code': 'invalid', 'name': 2},
      {'code': '  ', 'name': 'Invalid'},
      {'code': 'invalid', 'name': '\n'},
      _flex,
    ]);
    expect(products.map((p) => p.code), ['bocFlex']);
    expect(products.single.name, 'BOC Flex');
  });

  test('unknown products retain server order and remain read-only', () {
    final products = SavingsProductData.parseCatalogue([
      {'code': 'future', 'name': 'Future', 'walletType': 'bocFlex'},
      _flex,
      {'code': 'target', 'name': 'Target'},
    ]);
    expect(products.map((p) => p.code), ['future', 'bocFlex', 'target']);
    expect(products.map((p) => p.canOpenFlex), [false, true, false]);
  });

  test('Flex navigation requires matching code and wallet type', () {
    for (final walletType in <Object?>[null, '', 'other', 123]) {
      final products = SavingsProductData.parseCatalogue([
        {..._flex, 'walletType': walletType},
      ]);
      expect(products.single.canOpenFlex, isFalse);
    }
  });

  test('catalogue collapses identical rows without changing server order', () {
    final products = SavingsProductData.parseCatalogue([
      _flex,
      {'code': 'future', 'name': 'Future'},
      {..._flex},
    ]);
    expect(products.map((p) => p.code), ['bocFlex', 'future']);
    expect(() => products.clear(), throwsUnsupportedError);
  });

  test('conflicting valid duplicates are omitted and cannot reappear', () {
    for (final conflict in <Map<String, Object?>>[
      {'name': 'Different name'},
      {'walletType': 'different'},
      {'productKind': 'different'},
    ]) {
      final products = SavingsProductData.parseCatalogue([
        _flex,
        {'code': 'future', 'name': 'Future'},
        {..._flex, ...conflict},
        _flex,
      ]);
      expect(products.map((p) => p.code), ['future']);
    }
  });

  test('invalid duplicate cannot suppress a valid product', () {
    final products = SavingsProductData.parseCatalogue([
      _flex,
      {'code': 'bocFlex', 'name': null},
    ]);
    expect(products.single.canOpenFlex, isTrue);
  });

  test('untyped financial terms do not become catalogue display fields', () {
    final products = SavingsProductData.parseCatalogue([
      {
        ..._flex,
        'rate': {'malformed': true},
        'minimumAmount': 'unknown',
      },
    ]);
    expect(products.single.name, 'BOC Flex');
    expect(products.single.canOpenFlex, isTrue);
  });

  test(
    'derived catalogue follows Home updates and clear without fetching',
    () async {
      final service = _HomeService([
        NotifierState.done(
          UserHomeData.fromJson({
            'savingsProducts': [_flex],
          }),
        ),
        NotifierState.done(
          UserHomeData.fromJson({
            'savingsProducts': [
              {'code': 'future', 'name': 'Future'},
            ],
          }),
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          homeServiceProvider.overrideWithValue(service),
          authSessionProvider.overrideWith(SavingsSession.new),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(savingsProductsProvider), isEmpty);
      expect(service.calls, 0);
      final home = container.read(userHomeProvider.notifier);
      await home.load();
      expect(container.read(savingsProductsProvider).single.code, 'bocFlex');
      expect(service.calls, 1);
      await home.load();
      expect(container.read(savingsProductsProvider).single.code, 'future');
      expect(service.calls, 2);
      home.clear();
      expect(container.read(savingsProductsProvider), isEmpty);
      expect(service.calls, 2);
    },
  );
}
