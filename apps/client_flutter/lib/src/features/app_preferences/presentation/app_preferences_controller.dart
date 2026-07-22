import 'package:flutter/material.dart';

import '../data/app_preferences_store.dart';
import '../domain/app_preferences.dart';

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController({required this.store});

  final AppPreferencesStore store;

  AppPreferences _preferences = AppPreferences.defaults;
  bool _initialized = false;
  Object? _lastError;

  AppPreferences get preferences => _preferences;
  bool get initialized => _initialized;
  Object? get lastError => _lastError;

  Future<void> initialize() async {
    // Load failures must propagate so the app can surface a startup error
    // page (see DndTableApp). Save failures are handled separately in _save.
    _preferences = await store.load();
    _lastError = null;
    _initialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) {
    return _save(_preferences.copyWith(themeMode: mode));
  }

  Future<void> setSeedColor(Color color) {
    return _save(_preferences.copyWith(seedColorValue: color.toARGB32()));
  }

  Future<void> setDefaultDice(String notation) {
    final trimmed = notation.trim();
    if (trimmed.isEmpty) return Future.value();
    return _save(_preferences.copyWith(defaultDice: trimmed));
  }

  Future<void> setCompactLists(bool value) {
    return _save(_preferences.copyWith(compactLists: value));
  }

  Future<void> setConfirmBeforeRoll(bool value) {
    return _save(_preferences.copyWith(confirmBeforeRoll: value));
  }

  Future<void> setDefaultCreationMethod(String value) {
    return _save(_preferences.copyWith(defaultCreationMethod: value));
  }

  Future<void> setShowCharacterSources(bool value) {
    return _save(_preferences.copyWith(showCharacterSources: value));
  }

  Future<void> setShowEncumbrance(bool value) {
    return _save(_preferences.copyWith(showEncumbrance: value));
  }

  Future<void> setDefaultCharacterTab(String value) {
    return _save(_preferences.copyWith(defaultCharacterTab: value));
  }

  Future<void> setHighContrastTheme(bool value) {
    return _save(_preferences.copyWith(highContrastTheme: value));
  }

  Future<void> setDynamicSchemeVariant(String value) {
    return _save(_preferences.copyWith(dynamicSchemeVariant: value));
  }

  Future<void> setLogCharacterRuntimeChanges(bool value) {
    return _save(_preferences.copyWith(logCharacterRuntimeChanges: value));
  }

  /// Clears [lastError] once the UI has surfaced it to the user.
  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> _save(AppPreferences next) async {
    final previous = _preferences;
    try {
      await store.save(next);
      _preferences = next;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _preferences = previous;
      _lastError = error;
      notifyListeners();
      throw error;
    }
  }
}
