import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
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
    expect(controller.preferences.showCharacterSources, isTrue);
    expect(
      controller.preferences.toJson(),
      isNot(contains('showEncumbrance')),
    );
    expect(controller.preferences.defaultCharacterTab, 'overview');
    expect(controller.preferences.highContrastTheme, isFalse);
    expect(controller.preferences.dynamicSchemeVariant, 'tonalSpot');
    expect(controller.preferences.logCharacterRuntimeChanges, isTrue);
    expect(controller.preferences.groupConsecutiveChatMessages, isTrue);
    // Task 1.3 新增自定义项的默认值。
    expect(controller.preferences.defaultRollMode, 'normal');
    expect(controller.preferences.quickDicePresets, isEmpty);
    expect(controller.preferences.messageDensity, 'standard');
    expect(controller.preferences.fontScale, 'system');
    expect(controller.preferences.hpWarningThreshold, 0.3);
    expect(controller.preferences.returnToChatAfterRoll, isTrue);
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
    await controller.setShowCharacterSources(false);
    await controller.setDefaultCharacterTab('equipment');
    await controller.setHighContrastTheme(true);
    await controller.setDynamicSchemeVariant('fidelity');
    await controller.setLogCharacterRuntimeChanges(false);
    await controller.setGroupConsecutiveChatMessages(false);
    // Task 1.3 新增自定义项。
    await controller.setDefaultRollMode('advantage');
    await controller.setQuickDicePresets(const ['1d20+5', '8d6', '2d20kh1']);
    await controller.setMessageDensity('comfortable');
    await controller.setFontScale('large');
    await controller.setHpWarningThreshold(0.5);
    await controller.setReturnToChatAfterRoll(false);

    final reloaded = AppPreferencesController(store: store);
    await reloaded.initialize();

    expect(notifications, 16);
    expect(reloaded.preferences.themeMode, ThemeMode.dark);
    expect(reloaded.preferences.defaultDice, '2d20kh1');
    expect(reloaded.preferences.compactLists, isTrue);
    expect(reloaded.preferences.confirmBeforeRoll, isTrue);
    expect(reloaded.preferences.showCharacterSources, isFalse);
    expect(reloaded.preferences.defaultCharacterTab, 'equipment');
    expect(reloaded.preferences.highContrastTheme, isTrue);
    expect(reloaded.preferences.dynamicSchemeVariant, 'fidelity');
    expect(reloaded.preferences.logCharacterRuntimeChanges, isFalse);
    expect(reloaded.preferences.groupConsecutiveChatMessages, isFalse);
    expect(reloaded.preferences.defaultRollMode, 'advantage');
    expect(reloaded.preferences.quickDicePresets, ['1d20+5', '8d6', '2d20kh1']);
    expect(reloaded.preferences.messageDensity, 'comfortable');
    expect(reloaded.preferences.fontScale, 'large');
    expect(reloaded.preferences.hpWarningThreshold, 0.5);
    expect(reloaded.preferences.returnToChatAfterRoll, isFalse);
  });

  test('quickDicePresets rejects more than 6 entries', () async {
    final store = InMemoryAppPreferencesStore();
    final controller = AppPreferencesController(store: store);
    await controller.initialize();

    await controller.setQuickDicePresets(const [
      '1d20',
      '2d6',
      '3d8',
      '4d10',
      '5d12',
      '6d4',
      '7d20',
    ]);

    expect(controller.preferences.quickDicePresets.length, 6);
    expect(controller.preferences.quickDicePresets.last, '6d4');
  });

  test('hpWarningThreshold clamps to 0..1 range', () async {
    final store = InMemoryAppPreferencesStore();
    final controller = AppPreferencesController(store: store);
    await controller.initialize();

    await controller.setHpWarningThreshold(-0.5);
    expect(controller.preferences.hpWarningThreshold, 0.0);

    await controller.setHpWarningThreshold(1.5);
    expect(controller.preferences.hpWarningThreshold, 1.0);
  });

  test(
    'rolls back to the previous value when the store throws on save',
    () async {
      final store = _ThrowingSaveStore(AppPreferences.defaults);
      final controller = AppPreferencesController(store: store);
      await controller.initialize();

      Object? caught;
      try {
        await controller.setThemeMode(ThemeMode.dark);
      } catch (error) {
        caught = error;
      }

      expect(caught, isNotNull);
      expect(controller.preferences.themeMode, ThemeMode.system);
      expect(controller.lastError, isNotNull);
    },
  );

  test('clears lastError after a successful save', () async {
    final store = _ThrowingSaveStore(AppPreferences.defaults);
    final controller = AppPreferencesController(store: store);
    await controller.initialize();

    try {
      await controller.setThemeMode(ThemeMode.dark);
    } catch (_) {
      // ignore
    }
    expect(controller.lastError, isNotNull);

    store.throwOnSave = false;
    await controller.setThemeMode(ThemeMode.dark);

    expect(controller.preferences.themeMode, ThemeMode.dark);
    expect(controller.lastError, isNull);
  });

  test(
    'keeps every preference after rebuilding the controller from store',
    () async {
      final store = InMemoryAppPreferencesStore();
      final first = AppPreferencesController(store: store);
      await first.initialize();

      await first.setThemeMode(ThemeMode.dark);
      await first.setSeedColor(const Color(0xff123456));
      await first.setDefaultDice('3d6');
      await first.setCompactLists(true);
      await first.setConfirmBeforeRoll(true);
      await first.setShowCharacterSources(false);
      await first.setDefaultCharacterTab('equipment');
      await first.setHighContrastTheme(true);
      await first.setDynamicSchemeVariant('vibrant');
      await first.setLogCharacterRuntimeChanges(false);
      await first.setGroupConsecutiveChatMessages(false);
      // Task 1.3 新增自定义项。
      await first.setDefaultRollMode('disadvantage');
      await first.setQuickDicePresets(const ['1d20', '2d6+3']);
      await first.setMessageDensity('compact');
      await first.setFontScale('medium');
      await first.setHpWarningThreshold(0.25);
      await first.setReturnToChatAfterRoll(false);

      final reloaded = AppPreferencesController(store: store);
      await reloaded.initialize();

      expect(reloaded.preferences.themeMode, ThemeMode.dark);
      expect(
        reloaded.preferences.seedColorValue,
        const Color(0xff123456).toARGB32(),
      );
      expect(reloaded.preferences.defaultDice, '3d6');
      expect(reloaded.preferences.compactLists, isTrue);
      expect(reloaded.preferences.confirmBeforeRoll, isTrue);
      expect(reloaded.preferences.showCharacterSources, isFalse);
      expect(reloaded.preferences.defaultCharacterTab, 'equipment');
      expect(reloaded.preferences.highContrastTheme, isTrue);
      expect(reloaded.preferences.dynamicSchemeVariant, 'vibrant');
      expect(reloaded.preferences.logCharacterRuntimeChanges, isFalse);
      expect(reloaded.preferences.groupConsecutiveChatMessages, isFalse);
      expect(reloaded.preferences.defaultRollMode, 'disadvantage');
      expect(reloaded.preferences.quickDicePresets, ['1d20', '2d6+3']);
      expect(reloaded.preferences.messageDensity, 'compact');
      expect(reloaded.preferences.fontScale, 'medium');
      expect(reloaded.preferences.hpWarningThreshold, 0.25);
      expect(reloaded.preferences.returnToChatAfterRoll, isFalse);
    },
  );
}

class _ThrowingSaveStore implements AppPreferencesStore {
  _ThrowingSaveStore(AppPreferences initial) : _current = initial;

  AppPreferences _current;
  bool throwOnSave = true;

  @override
  Future<AppPreferences> load() async => _current;

  @override
  Future<void> save(AppPreferences preferences) async {
    if (throwOnSave) {
      throw StateError('disk full');
    }
    _current = preferences;
  }
}
