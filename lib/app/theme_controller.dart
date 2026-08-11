import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

const themePreferenceKey = 'boctrust.theme_mode';

enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.storageValue);

  final String storageValue;

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  static AppThemeMode parse(String? value) {
    return AppThemeMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => AppThemeMode.system,
    );
  }

  AppThemeMode get next => switch (this) {
    AppThemeMode.system => AppThemeMode.light,
    AppThemeMode.light => AppThemeMode.dark,
    AppThemeMode.dark => AppThemeMode.system,
  };
}

class ThemeControllerState {
  const ThemeControllerState(this.mode);

  final AppThemeMode mode;

  ThemeMode get themeMode => mode.themeMode;
}

class ThemeController extends Notifier<ThemeControllerState> {
  @override
  ThemeControllerState build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    return ThemeControllerState(
      AppThemeMode.parse(preferences.getString(themePreferenceKey)),
    );
  }

  Future<void> selectMode(AppThemeMode mode) async {
    state = ThemeControllerState(mode);
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(themePreferenceKey, mode.storageValue);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist theme mode',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> cycleMode() => selectMode(state.mode.next);
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeControllerState>(
      ThemeController.new,
    );
