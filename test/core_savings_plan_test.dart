import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/savings/model/savings_plan_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_savings_plan_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [data] in the Core envelope, recording it.
class _Core implements HttpClientAdapter {
  _Core([this.data]);
  final Object? data;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'message': 'ok', 'data': data, 'meta': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

CoreSavingsPlanService _service(_Core core) => CoreSavingsPlanService(
  ApiService(
    Dio(BaseOptions(baseUrl: 'https://core.test/api/v1'))
      ..httpClientAdapter = core,
  ),
);

Map<String, Object?> _plan({String status = 'active'}) => {
  'planId': 'p1',
  'productCode': 'bocSmartSave',
  'planName': 'Rent',
  'targetAmount': '100000',
  'principalAmount': '5000.00',
  'interestEarned': '0',
  'tenorDays': 90,
  'maturityDate': '2027-01-08',
  'status': status,
  'currentInterestRatePercent': '8.5',
};

void main() {
  // Plan amounts arrive as Naira decimal strings.
  test('amounts read as Naira', () {
    final groups = SavingsProductGroup.listFromJson([
      {
        'accountNumber': '1100919408',
        'productCode': 'bocSmartSave',
        'productName': 'Boc SmartSave',
        'productInterestRatePercent': '8.5',
        'defaultTenorDays': 90,
        'accountBalance': '1250000',
        'plans': [
          _plan(),
          _plan(status: 'paused_by_bank'),
          {..._plan(), 'principalAmount': 'abc'},
        ],
      },
      {'productCode': 'bocPadi', 'productName': 'Padi', 'plans': []},
    ]);

    final group = groups.single;
    expect(group.type, SavingsProductType.smartSave);
    expect(group.accountNumber, '1100919408');
    expect(group.plans.first.principal, '5000.00');
    expect(group.plans.first.target, '100000');
    expect(group.plans.first.status, SavingsPlanStatus.active);
    expect(group.plans[1].status, SavingsPlanStatus.unknown);
    // A plan whose amount cannot be read is kept, not hidden.
    expect(group.plans, hasLength(3));
    expect(group.plans.last.principal, isNull);
  });

  test('reads accrued interest and the early-withdrawal fee', () {
    final plan = SavingsPlan.tryParse({
      ..._plan(),
      'accruedInterest': '120.40',
      'earlyWithdrawalFeePercent': '2.5',
    })!;

    expect(plan.accruedInterest, '120.40');
    expect(plan.earlyWithdrawalFeePercent, '2.5');
  });

  test('plan detail keeps events without their references', () {
    final detail = SavingsPlanDetail.fromJson({
      ..._plan(),
      'accountNumber': '1100919408',
      'events': [
        {
          'eventType': 'top_up',
          'amount': '2500.00',
          'reference': 'REF-1',
          'createdAt': '2026-10-09T10:00:00Z',
        },
      ],
    });

    final event = detail.events.single;
    expect(event.type, SavingsPlanEventType.topUp);
    expect(event.amount, '2500.00');
    expect(event.props, isNot(contains('REF-1')));
  });

  test('plans are filtered by product and logged in full', () async {
    final core = _Core(<Object?>[]);
    final service = _service(core);

    await service.getPlans(SavingsProductType.fixed);
    await service.getPlan('p/1');

    final [list, detail] = core.requests;
    expect(list.path, '/me/savings-plans');
    expect(list.queryParameters, {'productCode': 'boctrustFixedDeposit'});
    expect(
      list.extra,
      isNot(contains(LoggingInterceptor.privacySensitivePathKey)),
    );
    expect(detail.path, '/me/savings-plans/p%2F1');
    expect(
      detail.extra,
      isNot(contains(LoggingInterceptor.privacySensitivePathKey)),
    );
  });

  test('funding sends Naira to the encoded plan', () async {
    final core = _Core({
      'planId': 'p/1',
      'status': 'active',
      'principalAmount': '7500.00',
    });

    final result = await _service(core).fundPlan('p/1', '2500.00');

    final request = core.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/me/savings-plans/p%2F1/fund');
    expect(request.data, {'amount': '2500.00'});
    expect(result.data!.principalAmount, '7500.00');
  });
}
