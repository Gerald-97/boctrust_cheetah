import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/module/account/provider/user_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/bank_product_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/home/model/user_home_model.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'support/flow_harness.dart';
import 'support/responsive_fixtures.dart';
import 'support/savings_fixtures.dart';

Map<String, Object?> _account(
  String code,
  String name,
  String number,
  String balance, {
  String status = 'active',
}) => {
  'productCode': code,
  'productName': name,
  'accountNumber': number,
  'status': status,
  'availableBalance': balance,
  'ledgerBalance': balance,
};

final _accounts = CustomerBankAccountsData.fromJson({
  'totalAvailableBalance': 1,
  'products': [
    _account('bocFlex', 'Boc Flex', '0000000001', '7654.30'),
    _account(
      'regular_savings',
      'Regular Savings',
      '0000000002',
      '100.00',
      status: 'frozen',
    ),
  ],
});

class _Accounts extends CustomerBankAccountsNotifier {
  _Accounts(this.initial);
  final NotifierState<CustomerBankAccountsData> initial;

  @override
  NotifierState<CustomerBankAccountsData> build() => initial;

  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async => state;
}

final _catalogue = NotifierState.done(
  CoreBankProduct.listFromJson([
    {'code': 'bocFlex', 'name': 'Boc Flex', 'interestRate': 2.5},
    {'code': 'regular_savings', 'name': 'Regular Savings', 'interestRate': 4.5},
    {
      'code': 'fixed_deposit',
      'name': 'Fixed Deposit',
      'description': 'Lock funds for a fixed term.',
      'interestRate': 12.5,
      'tenure': 90,
      'productDiscriminator': 'FixedDeposit',
    },
  ]),
);

class _Products extends CoreBankProductsNotifier {
  _Products(this.initial);
  final NotifierState<List<CoreBankProduct>> initial;

  @override
  NotifierState<List<CoreBankProduct>> build() => initial;

  @override
  Future<NotifierState<List<CoreBankProduct>>> load() async => state;
}

class _Home extends LayoutHome {
  @override
  Future<NotifierState<UserHomeData>> load() async => state;
}

class _HomeWithProducts extends UserHomeNotifier {
  @override
  NotifierState<UserHomeData> build() => NotifierState.done(
    UserHomeData.fromJson({
      'flexWallet': {
        'currency': 'NGN',
        'availableBalance': '7654.30',
        'ledgerBalance': '7654.30',
        'status': 'active',
      },
      'savingsProducts': [
        {'code': 'bocFlex', 'name': 'Boc Flex'},
        {'code': 'bocSmartSave', 'name': 'Boc SmartSave'},
        {'code': 'boctrustFixedDeposit', 'name': 'Boc Fixed Deposit'},
        {'code': 'bocPadi', 'name': 'Boc Padi'},
      ],
    }),
  );

  @override
  Future<NotifierState<UserHomeData>> load() async => state;
}

class _LoadingHome extends UserHomeNotifier {
  @override
  NotifierState<UserHomeData> build() => const NotifierState.loading();

  @override
  Future<NotifierState<UserHomeData>> load() async => state;
}

class _HiddenBalance extends HomeBalanceHiddenNotifier {
  @override
  bool build() => true;
}

class _Transactions extends CoreAccountService {
  _Transactions({this.reversed = false}) : super(null);

  final bool reversed;

  @override
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async => NotifierState.done(
    CoreTransactionPage(
      rows: [
        CoreAccountTransaction(
          id: 'txn-1',
          type: CoreTransactionType.debit,
          amount: '1250.00',
          balance: '6404.30',
          narration: 'Electricity payment',
          reference: 'BILL-123',
          date: DateTime.utc(2026, 10, 10, 12, 30),
          reversed: reversed,
        ),
      ],
      page: const CorePage(page: 1, pageSize: 20, total: 1, totalPages: 1),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  String route, {
  required NotifierState<CustomerBankAccountsData> accounts,
  NotifierState<List<CoreBankProduct>>? products,
  bool loadingHome = false,
  bool homeWithProducts = false,
  bool historyAvailable = false,
  CoreAccountService? accountService,
  bool hidden = false,
  Size viewport = const Size(800, 2000),
}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await pumpFlow(
    tester,
    route: route,
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      if (historyAvailable)
        featureAvailabilityProvider(
          FeatureCapability.coreAccountHistory,
        ).overrideWithValue(FeatureAvailability.available),
      if (accountService != null)
        coreAccountServiceProvider.overrideWithValue(accountService),
      if (hidden) homeBalanceHiddenProvider.overrideWith(_HiddenBalance.new),
      userProfileProvider.overrideWith(LayoutProfile.new),
      userHomeProvider.overrideWith(
        loadingHome
            ? _LoadingHome.new
            : homeWithProducts
            ? _HomeWithProducts.new
            : _Home.new,
      ),
      customerBankAccountsProvider.overrideWith(() => _Accounts(accounts)),
      coreBankProductsProvider.overrideWith(
        () => _Products(products ?? _catalogue),
      ),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('tapping a Home transaction opens its details', (tester) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: NotifierState.done(_accounts),
      historyAvailable: true,
      accountService: _Transactions(),
      viewport: const Size(360, 800),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('Electricity payment'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Electricity payment'));
    await tester.pumpAndSettle();

    expect(find.text('Account transaction'), findsNothing);
    expect(find.text('Type'), findsNothing);
    expect(find.text('Electricity payment'), findsWidgets);
    expect(find.text('-₦1,250.00'), findsOneWidget);
    expect(find.text('BILL-123'), findsOneWidget);
    expect(
      find.text(
        DateFormat(
          'd MMM yyyy, h:mm a',
        ).format(DateTime.utc(2026, 10, 10, 12, 30).toLocal()),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reversed Home transaction shows a marker in row and sheet', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: NotifierState.done(_accounts),
      historyAvailable: true,
      accountService: _Transactions(reversed: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Electricity payment'));
    expect(find.byTooltip('Reversed transaction'), findsOneWidget);

    await tester.tap(find.text('Electricity payment'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Reversed transaction'), findsNWidgets(2));
    expect(find.text('Reversed'), findsOneWidget);
  });

  testWidgets('Home transaction details mask amounts when balance is hidden', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: NotifierState.done(_accounts),
      historyAvailable: true,
      accountService: _Transactions(),
      hidden: true,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.text('Electricity payment'));
    await tester.tap(find.text('Electricity payment'));
    await tester.pumpAndSettle();

    final sheet = find.byType(AppActionSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('₦ ••••••')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: sheet, matching: find.text('-₦1,250.00')),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('₦6,404.30')),
      findsNothing,
    );
  });

  testWidgets('Home uses wallet and transaction shimmer while loading', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: const NotifierState.loading(),
      loadingHome: true,
      historyAvailable: true,
    );

    expect(find.byType(AppShimmerBlock), findsWidgets);
    expect(find.bySemanticsLabel('Loading your wallet'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString() == '_HomeTransactionsSkeleton',
      ),
      findsOneWidget,
    );
  });

  testWidgets('Save shows account placeholder and products while loading', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: const NotifierState.loading(),
      products: const NotifierState.loading(),
      loadingHome: true,
    );

    expect(find.byType(AppShimmerBlock), findsWidgets);
    expect(
      find.bySemanticsLabel('Loading your savings accounts'),
      findsOneWidget,
    );
    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Boc Padi'), findsOneWidget);
  });

  testWidgets('Home shows the Core Flex balance beside the User DVA', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: NotifierState.done(_accounts),
    );

    expect(find.text('₦7,654.30'), findsOneWidget);
    // LayoutHome's User Service flexWallet balance is never shown.
    expect(find.textContaining('1,234,567,890.12'), findsNothing);
    expect(find.textContaining('0123456789'), findsWidgets);
  });

  testWidgets('without a Core Flex account Home shows the User wallet', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.home,
      accounts: const NotifierState.error('Core is down'),
    );

    // LayoutHome's User Service flexWallet covers the missing Core account.
    expect(find.textContaining('1,234,567,890.12'), findsOneWidget);
    // Funding details still come from the User Service.
    expect(find.textContaining('0123456789'), findsWidgets);
  });

  testWidgets('Savings shows owned accounts and other published products', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(_accounts),
    );

    expect(find.text('Boc Flex'), findsOneWidget);
    expect(find.text('₦7,654.30'), findsOneWidget);
    expect(find.text('Regular Savings'), findsOneWidget);
    expect(find.text('Frozen'), findsOneWidget);
    expect(find.text('Your savings'), findsOneWidget);
    expect(find.textContaining('Licensed by the CBN'), findsOneWidget);
    expect(find.text('Account •••• 0001'), findsOneWidget);
    expect(find.text('Account •••• 0002'), findsOneWidget);
    expect(find.text('2.5% p.a.'), findsOneWidget);
    expect(find.text('4.5% p.a.'), findsOneWidget);
    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Boc Padi'), findsOneWidget);
    expect(find.text('Savings products'), findsOneWidget);
    expect(find.byType(BankProductCard), findsNWidgets(3));
    expect(find.text('Choose a plan'), findsNothing);
  });

  testWidgets('Save omits SmartSave and Fixed Deposit account numbers', (
    tester,
  ) async {
    final accounts = CustomerBankAccountsData.fromJson({
      'products': [
        _account('bocFlex', 'Boc Flex', '0000000001', '7654.30'),
        _account('bocSmartSave', 'Boc SmartSave', '0000000002', '5000.00'),
        _account(
          'boctrustFixedDeposit',
          'Boc Fixed Deposit',
          '0000000003',
          '1000.00',
        ),
      ],
    });
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(accounts),
    );

    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Account •••• 0001'), findsOneWidget);
    expect(find.text('Account •••• 0002'), findsNothing);
    expect(find.text('Account •••• 0003'), findsNothing);
  });

  testWidgets('Save shows all four published products with only Flex owned', (
    tester,
  ) async {
    final flexOnly = CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [_account('bocFlex', 'Boc Flex', '0000000001', '7654.30')],
    });
    final fourProducts = CoreBankProduct.listFromJson([
      {'code': 'bocFlex', 'name': 'Boc Flex'},
      {'code': 'bocSmartSave', 'name': 'Boc SmartSave'},
      {'code': 'boctrustFixedDeposit', 'name': 'Boc Fixed Deposit'},
      {'code': 'bocPadi', 'name': 'Boc Padi'},
    ]);
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(flexOnly),
      products: NotifierState.done(fourProducts),
      viewport: const Size(800, 2600),
    );

    expect(find.text('Your savings'), findsOneWidget);
    expect(find.text('Savings products'), findsOneWidget);
    expect(find.byType(BankProductCard), findsNWidgets(3));
    expect(find.text('Boc Flex'), findsOneWidget);
    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Boc Padi'), findsOneWidget);
    expect(find.text('₦7,654.30'), findsOneWidget);
  });

  testWidgets('Save fills missing Core products from User Home', (
    tester,
  ) async {
    final flexOnly = CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [_account('bocFlex', 'Boc Flex', '0000000001', '7654.30')],
    });
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(flexOnly),
      products: NotifierState.done(
        CoreBankProduct.listFromJson([
          {'code': 'bocFlex', 'name': 'Boc Flex'},
        ]),
      ),
      homeWithProducts: true,
      viewport: const Size(800, 2600),
    );

    expect(find.byType(BankProductCard), findsNWidgets(3));
    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Boc Padi'), findsOneWidget);
  });

  testWidgets('Save shows four products when the APIs publish only Flex', (
    tester,
  ) async {
    final flexOnly = CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [_account('bocFlex', 'Boc Flex', '0000000001', '7654.30')],
    });
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(flexOnly),
      products: NotifierState.done(
        CoreBankProduct.listFromJson([
          {'code': 'bocFlex', 'name': 'Boc Flex'},
        ]),
      ),
      viewport: const Size(800, 2600),
    );

    expect(find.text('Boc Flex'), findsOneWidget);
    expect(find.text('Boc SmartSave'), findsOneWidget);
    expect(find.text('Boc Fixed Deposit'), findsOneWidget);
    expect(find.text('Boc Padi'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byType(BankProductCard), findsNWidgets(3));

    await tester.tap(find.text('Boc Padi'));
    await tester.pumpAndSettle();
    expect(find.text('Savings products'), findsOneWidget);
    expect(find.textContaining('not available yet'), findsNothing);

    await tester.tap(find.text('Boc SmartSave'));
    await tester.pumpAndSettle();
    expect(find.text('Target Savings'), findsOneWidget);
    expect(find.textContaining('not available yet'), findsNothing);
  });

  testWidgets('an owned Padi account is not duplicated in the catalogue', (
    tester,
  ) async {
    final accounts = CustomerBankAccountsData.fromJson({
      'totalAvailableBalance': 1,
      'products': [
        _account('bocFlex', 'Boc Flex', '0000000001', '7654.30'),
        _account('bocPadi', 'Boc Padi', '0000000003', '50.00'),
      ],
    });
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(accounts),
      products: NotifierState.done(
        CoreBankProduct.listFromJson([
          {'code': 'bocFlex', 'name': 'Boc Flex'},
          {'code': 'bocPadi', 'name': 'Boc Padi'},
        ]),
      ),
      viewport: const Size(800, 2600),
    );

    expect(find.text('Boc Padi'), findsOneWidget);
    expect(find.byType(BankProductCard), findsNWidgets(2));
  });

  testWidgets(
    'Save keeps products visible and offers retry on catalogue error',
    (tester) async {
      await _pump(
        tester,
        AppRoutes.savingsHub,
        accounts: NotifierState.done(_accounts),
        products: const NotifierState.error('Product request failed'),
      );

      expect(
        find.text('Product details could not be refreshed'),
        findsOneWidget,
      );
      expect(find.text('Product request failed'), findsOneWidget);
      expect(find.text('Boc SmartSave'), findsOneWidget);
      expect(find.text('Retry'), findsWidgets);
    },
  );

  testWidgets('an empty Core catalogue does not add a product empty state', (
    tester,
  ) async {
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(_accounts),
      products: const NotifierState.done(<CoreBankProduct>[]),
    );

    expect(find.text('No savings products yet'), findsNothing);
    expect(find.text('Your savings'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
  });

  testWidgets('Savings cards fit a narrow phone', (tester) async {
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(_accounts),
      viewport: const Size(360, 800),
    );

    expect(find.text('Your savings'), findsOneWidget);
    expect(find.text('Account •••• 0002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owning every product shows only owned savings', (tester) async {
    await _pump(
      tester,
      AppRoutes.savingsHub,
      accounts: NotifierState.done(_accounts),
      products: NotifierState.done(
        CoreBankProduct.listFromJson([
          {'code': 'bocFlex', 'name': 'Boc Flex'},
          {'code': 'regular_savings', 'name': 'Regular Savings'},
        ]),
      ),
    );

    expect(find.text("You're all set"), findsNothing);
    expect(find.text('Your savings'), findsOneWidget);
  });
}
