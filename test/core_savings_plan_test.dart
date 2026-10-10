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
  'targetAmount': '10000000',
  'principalAmount': '500000',
  'interestEarned': '0',
  'tenorDays': 90,
  'maturityDate': '2027-01-08',
  'status': status,
  'currentInterestRatePercent': '8.5',
};

void main() {
  // Every amount input on this resource is documented in Kobo, and the
  // product balance falls back to summed principal, so all are Kobo.
  test('reads grouped plans with Kobo amounts as Naira', () {
    final groups = SavingsProductGroup.listFromJson([
      {
        'accountNumber': '1100919408',
        'productCode': 'bocSmartSave',
        'productName': 'Boc SmartSave',
        'productInterestRatePercent': '8.5',
        'defaultTenorDays': 90,
        'accountBalance': '1250000',
        'plans': [_plan(), _plan(status: 'paused_by_bank')],
      },
      {'productCode': 'bocPadi', 'productName': 'Padi', 'plans': []},
    ]);

    final group = groups.single;
    expect(group.type, SavingsProductType.smartSave);
    expect(group.balance, '12500.00');
    expect(group.plans.first.principal, '5000.00');
    expect(group.plans.first.target, '100000.00');
    expect(group.plans.first.status, SavingsPlanStatus.active);
    expect(group.plans.last.status, SavingsPlanStatus.unknown);
  });

  test('plan detail keeps events without their references', () {
    final detail = SavingsPlanDetail.fromJson({
      ..._plan(),
      'accountNumber': '1100919408',
      'events': [
        {
          'eventType': 'top_up',
          'amount': '250000',
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

  test('plans are filtered by product and logged by template', () async {
    final core = _Core(<Object?>[]);
    final service = _service(core);

    await service.getPlans(SavingsProductType.fixed);
    await service.getPlan('p/1');

    final [list, detail] = core.requests;
    expect(list.path, '/me/savings-plans');
    expect(list.queryParameters, {'productCode': 'boctrustFixedDeposit'});
    expect(
      list.extra[LoggingInterceptor.privacySensitivePathKey],
      '/me/savings-plans',
    );
    expect(detail.path, '/me/savings-plans/p%2F1');
    expect(
      detail.extra[LoggingInterceptor.privacySensitivePathKey],
      '/me/savings-plans/{planId}',
    );
  });
}
