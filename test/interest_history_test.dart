import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/app_router.dart';
import 'package:boctrust_savings_loan/app/feature_capability.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/route_arguments.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_page.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:boctrust_savings_loan/module/savings/model/interest_accrual_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_flex_interest_service.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_savings_plan_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/flow_harness.dart';
import 'support/savings_fixtures.dart';

class _Core implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'message': 'ok',
        'data': {'accruals': [], 'pagination': null},
        'meta': {},
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

InterestAccrual _accrual(String date, String interest) =>
    InterestAccrual.tryParse({
      'date': date,
      'balance': '100000.00',
      'ratePercent': '12.5',
      'interest': interest,
      'cumulativeInterest': '342.50',
    }, baseKey: 'balance')!;

class _Flex extends CoreFlexInterestService {
  const _Flex(this.pages) : super(null);
  final List<List<InterestAccrual>> pages;

  @override
  Future<NotifierState<InterestAccrualPage>> getAccruals({
    int page = 1,
    int pageSize = 30,
  }) async => NotifierState.done(
    InterestAccrualPage(
      accruals: pages[page - 1],
      page: CorePage(
        page: page,
        pageSize: pageSize,
        total: pages.length * pageSize,
        totalPages: pages.length,
      ),
    ),
  );
}

class _Plans extends CoreSavingsPlanService {
  const _Plans() : super(null);

  @override
  Future<NotifierState<InterestAccrualPage>> getPlanAccruals(
    String planId, {
    int page = 1,
    int pageSize = 30,
  }) async => const NotifierState.error('Not found.', statusCode: 404);
}

void main() {
  test('plan accruals use the encoded plan id and a page', () async {
    final core = _Core();
    final service = CoreSavingsPlanService(
      ApiService(
        Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
          ..httpClientAdapter = core,
      ),
    );

    await service.getPlanAccruals('p/1', page: 2);

    expect(core.requests.single.path, '/me/savings-plans/p%2F1/accruals');
    expect(core.requests.single.queryParameters, {'page': 2, 'pageSize': 30});
  });

  test('accruals read with their documented fields', () {
    final accrual = _accrual('2026-10-11', '34.25');

    expect(accrual.base, '100000.00');
    expect(accrual.interest, '34.25');
    expect(accrual.date, DateTime(2026, 10, 11));
  });

  testWidgets('the history screen lists days and pages on', (tester) async {
    await pumpFlow(
      tester,
      route: AppRoutes.interestHistory,
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        featureAvailabilityProvider(
          FeatureCapability.flexInterestView,
        ).overrideWithValue(FeatureAvailability.available),
        coreFlexInterestServiceProvider.overrideWithValue(
          _Flex([
            [_accrual('2026-10-11', '34.25')],
            [_accrual('2026-10-10', '33.10')],
          ]),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Flex interest history'), findsOneWidget);
    expect(find.text('₦34.25'), findsOneWidget);
    expect(find.text('11 Oct 2026'), findsOneWidget);

    await tester.ensureVisible(find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('10 Oct 2026'), findsOneWidget);
    expect(find.text('₦33.10'), findsOneWidget);
  });

  testWidgets('a plan that is no longer available says so', (tester) async {
    await pumpFlow(
      tester,
      route: AppRoutes.interestHistory,
      arguments: const AppRouteArguments(entityId: 'p1'),
      overrides: [
        authSessionProvider.overrideWith(SavingsSession.new),
        featureAvailabilityProvider(
          FeatureCapability.savingsPlansView,
        ).overrideWithValue(FeatureAvailability.available),
        coreSavingsPlanServiceProvider.overrideWithValue(const _Plans()),
      ],
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('This plan is no longer available.'), findsOneWidget);
  });
}
