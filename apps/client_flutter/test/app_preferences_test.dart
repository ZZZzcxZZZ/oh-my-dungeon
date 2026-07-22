import 'package:dnd_table_client/src/features/app_preferences/data/app_preferences_store.dart';
import 'package:dnd_table_client/src/features/app_preferences/domain/app_preferences.dart';
import 'package:dnd_table_client/src/features/app_preferences/presentation/app_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(controller.preferences.defaultCreationMethod, 'standard');
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
    await controller.setDefaultCreationMethod('standard');
    await controller.setShowCharacterSources(false);
    await controller.setShowEncumbrance(true);
    await controller.setDefaultCharacterTab('equipment');
    await controller.setHighContrastTheme(true);
    await controller.setDynamicSchemeVariant('fidelity');
    await controller.setLogCharacterRuntimeChanges(false);

    final reloaded = AppPreferencesController(store: store);
    await reloaded.initialize();

    expect(notifications, 11);
    expect(reloaded.preferences.themeMode, ThemeMode.dark);
    expect(reloaded.preferences.defaultDice, '2d20kh1');
    expect(reloaded.preferences.compactLists, isTrue);
    expect(reloaded.preferences.confirmBeforeRoll, isTrue);
    expect(reloaded.preferences.defaultCreationMethod, 'standard');
    expect(reloaded.preferences.showCharacterSources, isFalse);
    expect(reloaded.preferences.showEncumbrance, isTrue);
    expect(reloaded.preferences.defaultCharacterTab, 'equipment');
    expect(reloaded.preferences.highContrastTheme, isTrue);
    expect(reloaded.preferences.dynamicSchemeVariant, 'fidelity');
    expect(reloaded.preferences.logCharacterRuntimeChanges, isFalse);
  });

  test('migrates the previous quick-build default to the standard guide once', () async {
    SharedPreferences.setMockInitialValues({
      'app_preferences.default_creation_method': 'quick',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesAppPreferencesStore(preferences);

    final migrated = await store.load();

    expect(migrated.defaultCreationMethod, 'standard');
    expect(
      preferences.getBool('app_preferences.standard_guide_migrated'),
      isTrue,
    );
    expect(
      preferences.getString('app_preferences.default_creation_method'),
      'standard',
    );

    await store.save(migrated.copyWith(defaultCreationMethod: 'quick'));
    expect((await store.load()).defaultCreationMethod, 'quick');
  });

  test('rolls back to the previous value when the store throws on save', () async {
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
  });

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

  test('keeps every preference after rebuilding the controller from store', () async {
    final store = InMemoryAppPreferencesStore();
    final first = AppPreferencesController(store: store);
    await first.initialize();

    await first.setThemeMode(ThemeMode.dark);
    await first.setSeedColor(const Color(0xff123456));
    await first.setDefaultDice('3d6');
    await first.setCompactLists(true);
    await first.setConfirmBeforeRoll(true);
    await first.setDefaultCreationMethod('standard');
    await first.setShowCharacterSources(false);
    await first.setShowEncumbrance(true);
    await first.setDefaultCharacterTab('equipment');
    await first.setHighContrastTheme(true);
    await first.setDynamicSchemeVariant('vibrant');
    await first.setLogCharacterRuntimeChanges(false);

    final reloaded = AppPreferencesController(store: store);
    await reloaded.initialize();

    expect(reloaded.preferences.themeMode, ThemeMode.dark);
    expect(reloaded.preferences.seedColorValue, const Color(0xff123456).toARGB32());
    expect(reloaded.preferences.defaultDice, '3d6');
    expect(reloaded.preferences.compactLists, isTrue);
    expect(reloaded.preferences.confirmBeforeRoll, isTrue);
    expect(reloaded.preferences.defaultCreationMethod, 'standard');
    expect(reloaded.preferences.showCharacterSources, isFalse);
    expect(reloaded.preferences.showEncumbrance, isTrue);
    expect(reloaded.preferences.defaultCharacterTab, 'equipment');
    expect(reloaded.preferences.highContrastTheme, isTrue);
    expect(reloaded.preferences.dynamicSchemeVariant, 'vibrant');
    expect(reloaded.preferences.logCharacterRuntimeChanges, isFalse);
  });
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
