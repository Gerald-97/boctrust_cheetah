import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/app/services.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/beneficiary_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/core_submission_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/model/interbank_models.dart';
import 'package:boctrust_savings_loan/module/core_banking/provider/core_payments_providers.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_beneficiary_service.dart';
import 'package:boctrust_savings_loan/module/core_banking/service/core_transfer_service.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'support/savings_fixtures.dart';

class _Transfers extends CoreTransferService {
  _Transfers() : super(ApiService(Dio()));
  int sent = 0;

  @override
  Future<ServiceResponse<CoreTransferAck>> transferToOtherBank(
    InterbankTransferDraft draft,
  ) async {
    sent++;
    return const ServiceResponse(status: ServiceStatus.error, statusCode: 500);
  }
}

const _ada = Beneficiary(
  id: 'b1',
  type: BeneficiaryType.bankAccount,
  number: '0123456789',
  name: 'ADA OBI',
);

class _Beneficiaries extends CoreBeneficiaryService {
  _Beneficiaries() : super(ApiService(Dio()));
  NotifierState<bool> deleteReply = const NotifierState.error('No');

  @override
  Future<NotifierState<List<Beneficiary>>> list() async =>
      const NotifierState.done([_ada]);

  @override
  Future<NotifierState<Beneficiary>> add(Map<String, Object?> body) async =>
      const NotifierState.error('Duplicate', statusCode: 409);

  @override
  Future<NotifierState<bool>> delete(String id) async => deleteReply;
}

ProviderContainer _container(List<Override> overrides) {
  final container = ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(SavingsSession.new),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

const _draft = InterbankTransferDraft(
  bankCode: '000014',
  bankName: 'Zenith',
  accountNumber: '0123456789',
  accountName: 'ADA OBI',
  amountKobo: '5000',
);

void main() {
  test('an interbank 500 is a rejection the customer may retry', () async {
    final transfers = _Transfers();
    final container = _container([
      coreTransferServiceProvider.overrideWithValue(transfers),
    ]);
    final notifier = container.read(interbankTransferProvider.notifier);

    await notifier.submit(_draft);
    expect(
      container.read(interbankTransferProvider).outcome,
      const RejectedSubmission(CoreRejection.recipientUnresolved),
    );
    notifier.reset();
    await notifier.submit(_draft);
    expect(transfers.sent, 2);
  });

  test('beneficiaries change only after Core confirms', () async {
    final service = _Beneficiaries();
    final container = _container([
      coreBeneficiaryServiceProvider.overrideWithValue(service),
    ]);
    final notifier = container.read(beneficiariesProvider.notifier);
    await notifier.load();

    expect(await notifier.add({}), 'This beneficiary is already saved.');
    expect(await notifier.delete('b1'), 'No');
    expect(container.read(beneficiariesProvider).data, [_ada]);

    service.deleteReply = const NotifierState.done(true);
    expect(await notifier.delete('b1'), isNull);
    expect(container.read(beneficiariesProvider).data, isEmpty);
  });
}
