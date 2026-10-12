import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_summary.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_account_transactions.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_page.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_account_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:flutter/material.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _Accounts extends CoreAccountService {
  _Accounts([this.pages = const [[]]]) : super(null);

  /// The rows of each page, first page first.
  final List<List<CoreAccountTransaction>> pages;
  final ranges = <CoreHistoryRange>[];

  /// When set, every later history read fails.
  bool failing = false;

  @override
  Future<NotifierState<CoreAccountSummary>> getAccountSummary(
    String accountNumber,
  ) async => NotifierState.done(
    CoreAccountSummary(
      accountNumber: accountNumber,
      status: CoreAccountStatus.active,
      name: 'ADA OBI',
      product: 'Boc Flex',
      availableBalance: '7654.30',
    ),
  );

  @override
  Future<NotifierState<CoreTransactionPage>> getAccountTransactions(
    String accountNumber,
    CoreHistoryRange range, {
    int page = 1,
    int pageSize = 20,
    DateTime? today,
  }) async {
    ranges.add(range);
    if (failing) {
      return const NotifierState.error('Core is unreachable.', statusCode: 503);
    }
    return NotifierState.done(
      CoreTransactionPage(
        rows: pages[page - 1],
        page: CorePage(
          page: page,
          pageSize: pageSize,
          total: pages.length * pageSize,
          totalPages: pages.length,
        ),
      ),
    );
  }
}

CoreAccountTransaction _row(
  String id, {
  CoreTransactionType type = CoreTransactionType.debit,
  String amount = '1.00',
  String? narration,
  bool reversed = false,
}) => CoreAccountTransaction(
  id: id,
  type: type,
  amount: amount,
  narration: narration,
  reversed: reversed,
);

Future<void> _pumpDetail(WidgetTester tester, _Accounts accounts) async {
  await pumpFlow(
    tester,
    route: AppRoutes.bankAccountDetail,
    arguments: const AppRouteArguments(entityId: '1100919408'),
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      coreAccountServiceProvider.overrideWithValue(accounts),
      featureAvailabilityProvider(
        FeatureCapability.coreAccountActivity,
      ).overrideWithValue(FeatureAvailability.available),
      featureAvailabilityProvider(
        FeatureCapability.coreAccountHistory,
      ).overrideWithValue(FeatureAvailability.available),
    ],
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('account detail shows the live summary', (tester) async {
    await _pumpDetail(tester, _Accounts());

    expect(find.text('Boc Flex'), findsWidgets);
    expect(find.text('₦7,654.30'), findsOneWidget);
    expect(find.text('ADA OBI'), findsOneWidget);
  });

  testWidgets('history shows each row with its direction', (tester) async {
    await _pumpDetail(
      tester,
      _Accounts([
        [
          _row(
            '1',
            type: CoreTransactionType.credit,
            amount: '5000.00',
            narration: 'SALARY',
          ),
          _row('2', amount: '40.38', narration: 'POS'),
        ],
      ]),
    );

    expect(find.text('+₦5,000.00'), findsOneWidget);
    expect(find.text('-₦40.38'), findsOneWidget);
    expect(find.text('SALARY'), findsOneWidget);
    expect(find.text('POS'), findsOneWidget);
  });

  testWidgets('choosing a range re-reads that range', (tester) async {
    final accounts = _Accounts();
    await _pumpDetail(tester, accounts);

    await tester.tap(find.text('7 days'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(accounts.ranges.last, CoreHistoryRange.last7Days);
  });

  testWidgets('a reversed row says so', (tester) async {
    await _pumpDetail(
      tester,
      _Accounts([
        [_row('1', reversed: true)],
      ]),
    );

    expect(find.textContaining('Reversed'), findsOneWidget);
  });

  testWidgets('a later page never repeats a row', (tester) async {
    await _pumpDetail(
      tester,
      _Accounts([
        [_row('a', narration: 'ROW A'), _row('b', narration: 'ROW B')],
        [_row('b', narration: 'ROW B'), _row('c', narration: 'ROW C')],
      ]),
    );

    await tester.ensureVisible(find.text('Show more'));
    // Clear the bottom navigation.
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.text('Show more'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ROW A'), findsOneWidget);
    expect(find.text('ROW B'), findsOneWidget);
    expect(find.text('ROW C'), findsOneWidget);
    expect(find.text('Show more'), findsNothing);
  });

  testWidgets('empty history is not shown as activity', (tester) async {
    await _pumpDetail(tester, _Accounts());

    expect(find.text('No transactions in this period.'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the rows shown', (tester) async {
    final accounts = _Accounts([
      [_row('a', narration: 'POS')],
    ]);
    await _pumpDetail(tester, accounts);

    accounts.failing = true;
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Core is unreachable.'), findsOneWidget);
  });
}
