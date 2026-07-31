import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_repository.dart';
import '../domain/app_preferences.dart';

abstract class AppPreferencesStore {
  Future<AppPreferences> load();
  Future<void> save(AppPreferences preferences);
}

class SharedPreferencesAppPreferencesStore implements AppPreferencesStore {
  const SharedPreferencesAppPreferencesStore(
    this._preferences, [
    this.syncRepository,
  ]);

  final SharedPreferences _preferences;
  final SyncRepository? syncRepository;

  static const _themeModeKey = 'app_preferences.theme_mode';
  static const _seedColorKey = 'app_preferences.seed_color';
  static const _defaultDiceKey = 'app_preferences.default_dice';
  static const _compactListsKey = 'app_preferences.compact_lists';
  static const _confirmBeforeRollKey = 'app_preferences.confirm_before_roll';
  static const _showCharacterSourcesKey =
      'app_preferences.show_character_sources';
  static const _showEncumbranceKey = 'app_preferences.show_encumbrance';
  static const _defaultCharacterTabKey =
      'app_preferences.default_character_tab';
  static const _highContrastThemeKey = 'app_preferences.high_contrast_theme';
  static const _dynamicSchemeVariantKey =
      'app_preferences.dynamic_scheme_variant';
  static const _logCharacterRuntimeChangesKey =
      'app_preferences.log_character_runtime_changes';
  static const _groupConsecutiveChatMessagesKey =
      'app_preferences.group_consecutive_chat_messages';
  static const _defaultRollModeKey = 'app_preferences.default_roll_mode';
  static const _quickDicePresetsKey = 'app_preferences.quick_dice_presets';
  static const _messageDensityKey = 'app_preferences.message_density';
  static const _fontScaleKey = 'app_preferences.font_scale';
  static const _hpWarningThresholdKey = 'app_preferences.hp_warning_threshold';
  static const _returnToChatAfterRollKey =
      'app_preferences.return_to_chat_after_roll';

  @override
  Future<AppPreferences> load() async {
    return AppPreferences(
      themeMode: _themeModeFromString(_preferences.getString(_themeModeKey)),
      seedColorValue:
          _preferences.getInt(_seedColorKey) ??
          AppPreferences.defaults.seedColorValue,
      defaultDice:
          _preferences.getString(_defaultDiceKey) ??
          AppPreferences.defaults.defaultDice,
      compactLists:
          _preferences.getBool(_compactListsKey) ??
          AppPreferences.defaults.compactLists,
      confirmBeforeRoll:
          _preferences.getBool(_confirmBeforeRollKey) ??
          AppPreferences.defaults.confirmBeforeRoll,
      showCharacterSources:
          _preferences.getBool(_showCharacterSourcesKey) ??
          AppPreferences.defaults.showCharacterSources,
      showEncumbrance:
          _preferences.getBool(_showEncumbranceKey) ??
          AppPreferences.defaults.showEncumbrance,
      defaultCharacterTab:
          _preferences.getString(_defaultCharacterTabKey) ??
          AppPreferences.defaults.defaultCharacterTab,
      highContrastTheme:
          _preferences.getBool(_highContrastThemeKey) ??
          AppPreferences.defaults.highContrastTheme,
      dynamicSchemeVariant:
          _preferences.getString(_dynamicSchemeVariantKey) ??
          AppPreferences.defaults.dynamicSchemeVariant,
      logCharacterRuntimeChanges:
          _preferences.getBool(_logCharacterRuntimeChangesKey) ??
          AppPreferences.defaults.logCharacterRuntimeChanges,
      groupConsecutiveChatMessages:
          _preferences.getBool(_groupConsecutiveChatMessagesKey) ??
          AppPreferences.defaults.groupConsecutiveChatMessages,
      defaultRollMode:
          _preferences.getString(_defaultRollModeKey) ??
          AppPreferences.defaults.defaultRollMode,
      quickDicePresets:
          _preferences.getStringList(_quickDicePresetsKey) ??
          AppPreferences.defaults.quickDicePresets,
      messageDensity:
          _preferences.getString(_messageDensityKey) ??
          AppPreferences.defaults.messageDensity,
      fontScale:
          _preferences.getString(_fontScaleKey) ??
          AppPreferences.defaults.fontScale,
      hpWarningThreshold:
          _preferences.getDouble(_hpWarningThresholdKey) ??
          AppPreferences.defaults.hpWarningThreshold,
      returnToChatAfterRoll:
          _preferences.getBool(_returnToChatAfterRollKey) ??
          AppPreferences.defaults.returnToChatAfterRoll,
    );
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    await _preferences.setString(_themeModeKey, preferences.themeMode.name);
    await _preferences.setInt(_seedColorKey, preferences.seedColorValue);
    await _preferences.setString(_defaultDiceKey, preferences.defaultDice);
    await _preferences.setBool(_compactListsKey, preferences.compactLists);
    await _preferences.setBool(
      _confirmBeforeRollKey,
      preferences.confirmBeforeRoll,
    );
    await _preferences.setBool(
      _showCharacterSourcesKey,
      preferences.showCharacterSources,
    );
    await _preferences.setBool(
      _showEncumbranceKey,
      preferences.showEncumbrance,
    );
    await _preferences.setString(
      _defaultCharacterTabKey,
      preferences.defaultCharacterTab,
    );
    await _preferences.setBool(
      _highContrastThemeKey,
      preferences.highContrastTheme,
    );
    await _preferences.setString(
      _dynamicSchemeVariantKey,
      preferences.dynamicSchemeVariant,
    );
    await _preferences.setBool(
      _logCharacterRuntimeChangesKey,
      preferences.logCharacterRuntimeChanges,
    );
    await _preferences.setBool(
      _groupConsecutiveChatMessagesKey,
      preferences.groupConsecutiveChatMessages,
    );
    await _preferences.setString(
      _defaultRollModeKey,
      preferences.defaultRollMode,
    );
    await _preferences.setStringList(
      _quickDicePresetsKey,
      preferences.quickDicePresets,
    );
    await _preferences.setString(
      _messageDensityKey,
      preferences.messageDensity,
    );
    await _preferences.setString(_fontScaleKey, preferences.fontScale);
    await _preferences.setDouble(
      _hpWarningThresholdKey,
      preferences.hpWarningThreshold,
    );
    await _preferences.setBool(
      _returnToChatAfterRollKey,
      preferences.returnToChatAfterRoll,
    );
    final repo = syncRepository;
    if (repo != null) {
      await repo.enqueue(
        SyncOperation(
          id: 'vault:preferences:default:${DateTime.now().millisecondsSinceEpoch}',
          scope: 'vault',
          entityType: 'preferences',
          entityId: 'default',
          baseRevision: 0,
          payloadJson: jsonEncode(preferences.toJson()),
        ),
      );
    }
  }
}

class InMemoryAppPreferencesStore implements AppPreferencesStore {
  AppPreferences? _preferences;

  @override
  Future<AppPreferences> load() async {
    return _preferences ?? AppPreferences.defaults;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    _preferences = preferences;
  }
}

ThemeMode _themeModeFromString(String? value) {
  return switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
