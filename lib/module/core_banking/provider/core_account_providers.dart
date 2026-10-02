import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/services.dart';
import '../../onboarding/provider/auth_session_provider.dart';
import '../model/bank_product_models.dart';
import '../model/customer_bank_account_models.dart';
import '../service/core_account_service.dart';

final customerBankAccountsProvider =
    NotifierProvider<
      CustomerBankAccountsNotifier,
      NotifierState<CustomerBankAccountsData>
    >(CustomerBankAccountsNotifier.new);

final coreBankProductsProvider =
    NotifierProvider<
      CoreBankProductsNotifier,
      NotifierState<List<CoreBankProduct>>
    >(CoreBankProductsNotifier.new);

/// Session-scoped Core read, following `UserHomeNotifier`: the access token
/// that started a load must still be current when it lands, overlapping
/// loads share one request, a failed refresh keeps the last good data, and
/// [clear] drops state and any in-flight response.
abstract class _CoreSessionNotifier<T> extends Notifier<NotifierState<T>>
    with StaleResultGuard<NotifierState<T>> {
  Future<NotifierState<T>>? _inFlight;

  String get failureMessage;
  Future<NotifierState<T>> fetch(CoreAccountService service);

  @override
  NotifierState<T> build() {
    trackDisposal();
    ref.listen(authSessionProvider, (previous, next) {
      if (previous != next) clear();
    });
    return const NotifierState.idle();
  }

  Future<NotifierState<T>> load() {
    final session = ref.read(authSessionProvider);
    if (session == null || session.isExpired) {
      clear();
      return Future.value(state);
    }
    return _inFlight ??= _load(session.accessToken);
  }

  Future<NotifierState<T>> _load(String accessToken) async {
    final token = beginRequest();
    final retained = state.data;
    state = NotifierState.loading(data: retained);
    final result = await fetch(ref.read(coreAccountServiceProvider));
    if (!ref.mounted || !isCurrent(token)) return const NotifierState.idle();
    _inFlight = null;
    final session = ref.read(authSessionProvider);
    if (session == null ||
        session.isExpired ||
        session.accessToken != accessToken) {
      clear();
      return const NotifierState.idle();
    }
    state = result.isError && result.data == null && retained != null
        ? NotifierState.error(
            result.message ?? failureMessage,
            data: retained,
            statusCode: result.statusCode,
          )
        : result;
    return state;
  }

  void clear() {
    beginRequest();
    _inFlight = null;
    state = const NotifierState.idle();
  }
}

class CustomerBankAccountsNotifier
    extends _CoreSessionNotifier<CustomerBankAccountsData> {
  @override
  String get failureMessage => 'Unable to load your account balances.';

  @override
  Future<NotifierState<CustomerBankAccountsData>> fetch(
    CoreAccountService service,
  ) => service.getBankAccounts();
}

class CoreBankProductsNotifier
    extends _CoreSessionNotifier<List<CoreBankProduct>> {
  @override
  String get failureMessage => 'Unable to load savings products.';

  @override
  Future<NotifierState<List<CoreBankProduct>>> fetch(
    CoreAccountService service,
  ) => service.getBankProducts();
}
