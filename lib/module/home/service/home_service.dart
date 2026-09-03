import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/api_endpoints.dart';
import '../../../app/network.dart';
import '../../../app/services.dart';
import '../model/user_home_model.dart';

final homeServiceProvider = Provider<HomeService>(
  (ref) => HomeService(ref.watch(apiServiceProvider)),
);

class HomeService {
  const HomeService(this._api);
  final ApiService _api;

  Future<NotifierState<UserHomeData>> getOwnHome() async =>
      NotifierState.fromResponse(
        await _api.getData<UserHomeData>(
          ApiEndpoints.ownHome,
          parser: UserHomeData.fromJson,
        ),
      );
}
