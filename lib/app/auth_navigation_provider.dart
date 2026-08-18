import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'route_arguments.dart';

enum AuthDestination {
  bootstrap,
  onboarding,
  verificationMethod,
  signupOtp,
  createPassword,
  login,
  passwordReset,
  newDeviceOtp,
  createFirstPin,
  home,
}

enum AuthNavigationMode { push, replace, clearStack }

class AuthNavigationIntent extends Equatable {
  const AuthNavigationIntent({
    required this.id,
    required this.destination,
    required this.mode,
    this.message,
    this.messageTone = AppMessageTone.info,
  });

  final int id;
  final AuthDestination destination;
  final AuthNavigationMode mode;
  final String? message;
  final AppMessageTone messageTone;

  @override
  List<Object?> get props => [id, destination, mode, message, messageTone];
}

final authNavigationProvider =
    NotifierProvider<AuthNavigationNotifier, List<AuthNavigationIntent>>(
      AuthNavigationNotifier.new,
    );

class AuthNavigationNotifier extends Notifier<List<AuthNavigationIntent>> {
  int _nextId = 1;

  @override
  List<AuthNavigationIntent> build() => const [];

  void publish(
    AuthDestination destination, {
    required AuthNavigationMode mode,
    String? message,
    AppMessageTone messageTone = AppMessageTone.info,
  }) {
    state = [
      ...state,
      AuthNavigationIntent(
        id: _nextId++,
        destination: destination,
        mode: mode,
        message: message,
        messageTone: messageTone,
      ),
    ];
  }

  void acknowledge(int id) {
    state = state.where((intent) => intent.id != id).toList(growable: false);
  }
}
