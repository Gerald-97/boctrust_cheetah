import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Home wallet banner with the funding account the User Home response
/// returns in `dedicatedVirtualAccount`.
void main() {
  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onCopy}) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: BalanceCard(
              label: 'Wallet balance',
              balance: '₦0.00',
              hidden: false,
              onToggle: () {},
              accountNumber: '1100925452',
              bankName: 'BocTrust Microfinance Bank',
              onCopyAccountNumber: onCopy ?? () {},
              tier: 2,
            ),
          ),
        ),
      ),
    );
  }

  bool truncated(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines;

  testWidgets('the label stands alone above the balance', (tester) async {
    await pumpCard(tester);
    expect(find.text('Wallet balance'), findsOneWidget);
  });

  testWidgets('the account number and bank show in full at phone width', (
    tester,
  ) async {
    await pumpCard(tester);
    expect(find.text('1100925452'), findsOneWidget);
    expect(find.text('BocTrust Microfinance Bank'), findsOneWidget);
    expect(truncated(tester, '1100925452'), isFalse);
    expect(truncated(tester, 'BocTrust Microfinance Bank'), isFalse);
  });

  testWidgets('the copy button sits with the account number', (tester) async {
    var copies = 0;
    await pumpCard(tester, onCopy: () => copies++);
    await tester.tap(find.byTooltip('Copy account number'));
    expect(copies, 1);
    final number = tester.getRect(find.text('1100925452'));
    final copy = tester.getRect(find.byTooltip('Copy account number'));
    expect(copy.center.dy, closeTo(number.center.dy, 12));
  });
}
