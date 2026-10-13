import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/savings/model/savings_plan_models.dart';
import 'package:boctrust_savings_loan/module/savings/service/core_savings_plan_service.dart';
import 'package:dio/dio.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/customer_bank_account_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_account_providers.dart';
import 'package:boctrust_savings_loan/module/savings/provider/savings_plan_action_provider.dart';
import 'package:boctrust_savings_loan/module/savings/provider/savings_plan_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _SlowFund extends CoreSavingsPlanService {
  _SlowFund(this.reply) : super(null);
  final Completer<NotifierState<SavingsPlanActionResult>> reply;
  var reads = 0;
  var liquidations = 0;

  @override
  Future<NotifierState<SavingsPlanActionResult>> fundPlan(String _, String _) =>
      reply.future;

  @override
  Future<NotifierState<SavingsPlanActionResult>> liquidatePlan(String _) async {
    liquidations++;
    return const NotifierState.blocked('x');
  }

  @override
  Future<NotifierState<SavingsPlanDetail>> getPlan(String planId) async {
    reads++;
    return const NotifierState.blocked('x');
  }
}

class _Accounts extends CustomerBankAccountsNotifier {
  static var loads = 0;
  @override
  NotifierState<CustomerBankAccountsData> build() => const NotifierState.idle();
  @override
  Future<NotifierState<CustomerBankAccountsData>> load() async {
    loads++;
    return state;
  }
}

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

  test("a SmartSave draft becomes Core's create request", () {
    const draft = SavingsPlanDraft(
      type: SavingsProductType.smartSave,
      name: 'Rent',
      amount: '200,000',
      durationMonths: 6,
      autoSave: true,
      frequency: SavingsFrequency.weekly,
      recurringAmount: '5,000',
    );

    expect(draft.toCreateRequest()!.toJson(), {
      'productCode': 'bocSmartSave',
      'tenorDays': 180,
      'planName': 'Rent',
      'targetAmount': '200000.00',
      'saveFrequency': 'weekly',
      'recurringAmount': '5000.00',
    });
  });

  test('a Fixed Deposit draft sends only its term and name', () {
    const draft = SavingsPlanDraft(
      type: SavingsProductType.fixed,
      durationMonths: 3,
    );

    expect(draft.toCreateRequest()!.toJson(), {
      'productCode': 'boctrustFixedDeposit',
      'tenorDays': 90,
    });
  });

  test('liquidation sends no body and reads the payout', () async {
    final core = _Core({
      'planId': 'p1',
      'status': 'liquidated',
      'amountPaidOut': '5117.40',
      'interestAccrued': '120.40',
      'earlyWithdrawalFee': '3.01',
      'interestPaid': '117.39',
      'interestPending': '0.00',
    });

    final result = await _service(core).liquidatePlan('p1');

    final request = core.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/me/savings-plans/p1/liquidate');
    expect(request.data, isNull);
    final data = result.data!;
    expect(data.status, SavingsPlanStatus.liquidated);
    expect(data.amountPaidOut, '5117.40');
    expect(data.interestAccrued, '120.40');
    expect(data.earlyWithdrawalFee, '3.01');
    expect(data.interestPaid, '117.39');
    expect(data.interestPending, '0.00');
  });

  test(
    'a top-up still refreshes when its listener leaves while sending',
    () async {
      final reply = Completer<NotifierState<SavingsPlanActionResult>>();
      final service = _SlowFund(reply);
      _Accounts.loads = 0;
      final container = ProviderContainer(
        overrides: [
          coreSavingsPlanServiceProvider.overrideWithValue(service),
          customerBankAccountsProvider.overrideWith(_Accounts.new),
        ],
      );
      addTearDown(container.dispose);
      container.listen(savingsPlanDetailProvider('p1'), (_, _) {});
      await container.read(savingsPlanDetailProvider('p1').future);
      final sub = container.listen(savingsPlanActionProvider, (_, _) {});
      final sending = container
          .read(savingsPlanActionProvider.notifier)
          .fund('p1', '5.00');
      sub.close();
      // Let the provider dispose, as it would once the sheet is gone.
      await Future<void>.delayed(Duration.zero);

      reply.complete(
        const NotifierState.done(
          SavingsPlanActionResult(
            planId: 'p1',
            status: SavingsPlanStatus.active,
          ),
        ),
      );
      await sending;
      await container.read(savingsPlanDetailProvider('p1').future);

      expect(service.reads, 2);
      expect(_Accounts.loads, 1);
    },
  );

  test('a withdrawal started while a top-up sends sends nothing', () async {
    final reply = Completer<NotifierState<SavingsPlanActionResult>>();
    final service = _SlowFund(reply);
    final container = ProviderContainer(
      overrides: [
        coreSavingsPlanServiceProvider.overrideWithValue(service),
        customerBankAccountsProvider.overrideWith(_Accounts.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(savingsPlanActionProvider, (_, _) {});
    final actions = container.read(savingsPlanActionProvider.notifier);
    final funding = actions.fund('p1', '5.00');
    await actions.liquidate('p1');
    reply.complete(
      const NotifierState.done(
        SavingsPlanActionResult(planId: 'p1', status: SavingsPlanStatus.active),
      ),
    );
    await funding;

    final state = container.read(savingsPlanActionProvider);
    expect(service.liquidations, 0);
    expect(state.phase, SavingsPlanActionPhase.done);
    expect(
      state.viewFor(SavingsPlanAction.liquidate, 'p1').phase,
      SavingsPlanActionPhase.idle,
    );
  });
}
