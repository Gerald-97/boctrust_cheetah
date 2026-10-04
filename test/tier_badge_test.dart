import 'package:boctrust_savings_loan/app/theme.dart';
import 'package:boctrust_savings_loan/module/app_flow/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tier badges use the matching supplied artwork', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CheetahTheme.lightTheme,
        home: const Row(
          children: [
            BocTierBadge(tier: 1),
            BocTierBadge(tier: 2),
            BocTierBadge(tier: 3),
          ],
        ),
      ),
    );

    final assets = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toList();

    expect(assets, const [
      'assets/svg/tier_1.svg',
      'assets/svg/tier_2.svg',
      'assets/svg/tier_3.svg',
    ]);
  });
}
