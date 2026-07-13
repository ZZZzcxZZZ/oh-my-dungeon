import 'package:flutter/material.dart';

class AppPreferences {
  const AppPreferences({
    required this.themeMode,
    required this.seedColorValue,
    required this.defaultDice,
    required this.compactLists,
    required this.confirmBeforeRoll,
    required this.ruleset,
    required this.defaultCreationMethod,
    required this.showLegacyContent,
    required this.showCharacterSources,
    required this.showEncumbrance,
    required this.defaultCharacterTab,
    required this.highContrastTheme,
    required this.dynamicSchemeVariant,
    required this.logCharacterRuntimeChanges,
  });

  static const defaults = AppPreferences(
    themeMode: ThemeMode.system,
    seedColorValue: 0xff6750a4,
    defaultDice: '1d20',
    compactLists: false,
    confirmBeforeRoll: false,
    ruleset: 'dnd2024',
    defaultCreationMethod: 'quick',
    showLegacyContent: false,
    showCharacterSources: true,
    showEncumbrance: false,
    defaultCharacterTab: 'overview',
    highContrastTheme: false,
    dynamicSchemeVariant: 'tonalSpot',
    logCharacterRuntimeChanges: true,
  );

  final ThemeMode themeMode;
  final int seedColorValue;
  final String defaultDice;
  final bool compactLists;
  final bool confirmBeforeRoll;
  final String ruleset;
  final String defaultCreationMethod;
  final bool showLegacyContent;
  final bool showCharacterSources;
  final bool showEncumbrance;
  final String defaultCharacterTab;
  final bool highContrastTheme;
  final String dynamicSchemeVariant;
  final bool logCharacterRuntimeChanges;

  Color get seedColor => Color(seedColorValue);

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'seedColorValue': seedColorValue,
        'defaultDice': defaultDice,
        'compactLists': compactLists,
        'confirmBeforeRoll': confirmBeforeRoll,
        'ruleset': ruleset,
        'defaultCreationMethod': defaultCreationMethod,
        'showLegacyContent': showLegacyContent,
        'showCharacterSources': showCharacterSources,
        'showEncumbrance': showEncumbrance,
        'defaultCharacterTab': defaultCharacterTab,
        'highContrastTheme': highContrastTheme,
        'dynamicSchemeVariant': dynamicSchemeVariant,
        'logCharacterRuntimeChanges': logCharacterRuntimeChanges,
      };

  AppPreferences copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
    String? defaultDice,
    bool? compactLists,
    bool? confirmBeforeRoll,
    String? ruleset,
    String? defaultCreationMethod,
    bool? showLegacyContent,
    bool? showCharacterSources,
    bool? showEncumbrance,
    String? defaultCharacterTab,
    bool? highContrastTheme,
    String? dynamicSchemeVariant,
    bool? logCharacterRuntimeChanges,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      defaultDice: defaultDice ?? this.defaultDice,
      compactLists: compactLists ?? this.compactLists,
      confirmBeforeRoll: confirmBeforeRoll ?? this.confirmBeforeRoll,
      ruleset: ruleset ?? this.ruleset,
      defaultCreationMethod:
          defaultCreationMethod ?? this.defaultCreationMethod,
      showLegacyContent: showLegacyContent ?? this.showLegacyContent,
      showCharacterSources: showCharacterSources ?? this.showCharacterSources,
      showEncumbrance: showEncumbrance ?? this.showEncumbrance,
      defaultCharacterTab: defaultCharacterTab ?? this.defaultCharacterTab,
      highContrastTheme: highContrastTheme ?? this.highContrastTheme,
      dynamicSchemeVariant: dynamicSchemeVariant ?? this.dynamicSchemeVariant,
      logCharacterRuntimeChanges:
          logCharacterRuntimeChanges ?? this.logCharacterRuntimeChanges,
    );
  }
}
