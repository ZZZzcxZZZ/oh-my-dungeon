import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads defaults when no saved preferences exist', () async {
    final controller = AppPreferencesController(
      store: InMemoryAppPreferencesStore(),
    );

    await controller.initialize();

    expect(controller.preferences.themeMode, ThemeMode.system);
    expect(controller.preferences.defaultDice, '1d20');
    expect(controller.preferences.compactLists, isFalse);
    expect(controller.preferences.confirmBeforeRoll, isFalse);
    expect(controller.preferences.ruleset, 'dnd2024');
    expect(controller.preferences.defaultCreationMethod, 'quick');
    expect(controller.preferences.showLegacyContent, isFalse);
    expect(controller.preferences.showCharacterSources, isTrue);
    expect(controller.preferences.showEncumbrance, isFalse);
    expect(controller.preferences.defaultCharacterTab, 'overview');
    expect(controller.preferences.highContrastTheme, isFalse);
    expect(controller.preferences.dynamicSchemeVariant, 'tonalSpot');
    expect(controller.preferences.logCharacterRuntimeChanges, isTrue);
  });

  test('persists preference changes and notifies listeners', () async {
    final store = InMemoryAppPreferencesStore();
    final controller = AppPreferencesController(store: store);
    await controller.initialize();
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setDefaultDice('2d20kh1');
    await controller.setCompactLists(true);
    await controller.setConfirmBeforeRoll(true);
    await controller.setRuleset('mixed');
    await controller.setDefaultCreationMethod('standard');
    await controller.setShowLegacyContent(true);
    await controller.setShowCharacterSources(false);
    await controller.setShowEncumbrance(true);
    await controller.setDefaultCharacterTab('equipment');
    await controller.setHighContrastTheme(true);
    await controller.setDynamicSchemeVariant('fidelity');
    await controller.setLogCharacterRuntimeChanges(false);

    final reloaded = AppPreferencesController(store: store);
    await reloaded.initialize();

    expect(notifications, 13);
    expect(reloaded.preferences.themeMode, ThemeMode.dark);
    expect(reloaded.preferences.defaultDice, '2d20kh1');
    expect(reloaded.preferences.compactLists, isTrue);
    expect(reloaded.preferences.confirmBeforeRoll, isTrue);
    expect(reloaded.preferences.ruleset, 'mixed');
    expect(reloaded.preferences.defaultCreationMethod, 'standard');
    expect(reloaded.preferences.showLegacyContent, isTrue);
    expect(reloaded.preferences.showCharacterSources, isFalse);
    expect(reloaded.preferences.showEncumbrance, isTrue);
    expect(reloaded.preferences.defaultCharacterTab, 'equipment');
    expect(reloaded.preferences.highContrastTheme, isTrue);
    expect(reloaded.preferences.dynamicSchemeVariant, 'fidelity');
    expect(reloaded.preferences.logCharacterRuntimeChanges, isFalse);
  });
}
