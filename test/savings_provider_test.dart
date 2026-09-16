import 'package:boctrust_savings_loan/app/interceptors.dart';
import 'package:boctrust_savings_loan/app/network.dart';
import 'package:boctrust_savings_loan/module/home/provider/home_provider.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_enums.dart';
import 'package:boctrust_savings_loan/module/onboarding/model/auth_session.dart';
import 'package:boctrust_savings_loan/module/onboarding/provider/auth_session_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class MemorySession extends AuthSessionNotifier {
  @override
  AuthSession? build() => null;
  void setSession(AuthSession? session) => state = session;
}

AuthSession sessionFor(String user) => AuthSession(
  accessToken: 'test-token-$user',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  userId: user,
  identifierType: IdentifierType.email,
);

void main() {
  late ProviderContainer container;
  late Dio dio;
  late List<RequestOptions> requests;
  late List<RequestInterceptorHandler> pending;

  setUp(() {
    requests = [];
    pending = [];
    dio = Dio(BaseOptions(baseUrl: 'https://savings.test/api/v1'));
    container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(MemorySession.new),
        dioProvider.overrideWithValue(dio),
      ],
    );
    dio.interceptors.add(
      AuthInterceptor(
        readAccessToken: () async =>
            container.read(authSessionProvider)?.accessToken,
        readCurrentSession: () => container.read(authSessionProvider),
        expireSessionOnce: () async {},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          pending.add(handler);
        },
      ),
    );
  });
  tearDown(() {
    container.dispose();
    dio.close(force: true);
  });

  void signIn(String user) =>
      (container.read(authSessionProvider.notifier) as MemorySession)
          .setSession(sessionFor(user));

  Future<void> dispatched() =>
      Future<void>.delayed(const Duration(milliseconds: 10));

  void respond(int index, String balance, {int status = 200}) {
    pending[index].resolve(
      Response<Object?>(
        requestOptions: requests[index],
        statusCode: status,
        data: {
          'success': status == 200,
          'message': status == 200 ? 'Loaded' : 'Unavailable',
          'data': {
            'flexWallet': {
              'walletId': 'wallet-$index',
              'walletType': 'bocFlex',
              'availableBalance': balance,
              'currency': 'NGN',
              'status': 'active',
            },
            'savingsProducts': [
              {'code': 'bocFlex', 'name': 'Flex', 'walletType': 'bocFlex'},
            ],
          },
        },
      ),
    );
  }

  test('signed-out Home loads issue no private request', () async {
    final load = container.read(userHomeProvider.notifier).load();
    await dispatched();
    // Release a request on the old implementation so this regression cannot hang.
    if (pending.isNotEmpty) respond(0, '999');
    await load;
    expect(requests, isEmpty);
    expect(container.read(userHomeProvider).data, isNull);
  });

  test('overlapping screens share one authenticated Home request', () async {
    signIn('A');
    final notifier = container.read(userHomeProvider.notifier);
    final first = notifier.load();
    final second = notifier.load();
    await dispatched();
    for (var i = 0; i < pending.length; i++) {
      respond(i, '2500.0000');
    }
    await Future.wait([first, second]);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.uri.path, '/api/v1/users/me/home');
    expect(requests.single.headers['Authorization'], 'Bearer test-token-A');
    expect(
      container.read(userHomeProvider).data?.flexWallet?.availableBalance,
      '2500.0000',
    );
  });

  test(
    'clear invalidates a delayed response without a replacement request',
    () async {
      signIn('A');
      final notifier = container.read(userHomeProvider.notifier);
      final load = notifier.load();
      await dispatched();
      notifier.clear();
      respond(0, '999');
      final completed = await load;
      expect(container.read(userHomeProvider).data, isNull);
      expect(completed.data, isNull);
    },
  );

  test(
    'new session cannot reuse or display the previous session request',
    () async {
      signIn('A');
      final notifier = container.read(userHomeProvider.notifier);
      final a = notifier.load();
      await dispatched();
      signIn('B');
      final b = notifier.load();
      await dispatched();
      respond(0, '999');
      await a;
      expect(container.read(userHomeProvider).data, isNull);
      respond(1, '123.00');
      await b;
      expect(requests[1].headers['Authorization'], 'Bearer test-token-B');
      expect(
        container.read(userHomeProvider).data?.flexWallet?.availableBalance,
        '123.00',
      );
      (container.read(authSessionProvider.notifier) as MemorySession)
          .setSession(null);
      expect(container.read(userHomeProvider).data, isNull);
    },
  );

  test('failed refresh retains known data and permits a later retry', () async {
    signIn('A');
    final notifier = container.read(userHomeProvider.notifier);
    final first = notifier.load();
    await dispatched();
    respond(0, '25.00');
    await first;
    final failed = notifier.load();
    await dispatched();
    respond(1, '0', status: 503);
    await failed;
    expect(container.read(userHomeProvider).isError, isTrue);
    expect(
      container.read(userHomeProvider).data?.flexWallet?.availableBalance,
      '25.00',
    );
    final retry = notifier.load();
    await dispatched();
    respond(2, '30.00');
    await retry;
    expect(container.read(userHomeProvider).isDone, isTrue);
    expect(
      container.read(userHomeProvider).data?.flexWallet?.availableBalance,
      '30.00',
    );
  });
}
