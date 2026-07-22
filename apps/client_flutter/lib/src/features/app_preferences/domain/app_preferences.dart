import 'package:flutter/material.dart';

class AppPreferences {
  const AppPreferences({
    required this.themeMode,
    required this.seedColorValue,
    required this.defaultDice,
    required this.compactLists,
    required this.confirmBeforeRoll,
    required this.defaultCreationMethod,
    required this.showCharacterSources,
    required this.showEncumbrance,
    required this.defaultCharacterTab,
    required this.highContrastTheme,
    required this.dynamicSchemeVariant,
    required this.logCharacterRuntimeChanges,
    required this.groupConsecutiveChatMessages,
  });

  static const defaults = AppPreferences(
    themeMode: ThemeMode.system,
    seedColorValue: 0xff6750a4,
    defaultDice: '1d20',
    compactLists: false,
    confirmBeforeRoll: false,
    defaultCreationMethod: 'standard',
    showCharacterSources: true,
    showEncumbrance: false,
    defaultCharacterTab: 'overview',
    highContrastTheme: false,
    dynamicSchemeVariant: 'tonalSpot',
    logCharacterRuntimeChanges: true,
    groupConsecutiveChatMessages: true,
  );

  final ThemeMode themeMode;
  final int seedColorValue;
  final String defaultDice;
  final bool compactLists;
  final bool confirmBeforeRoll;
  final String defaultCreationMethod;
  final bool showCharacterSources;
  final bool showEncumbrance;
  final String defaultCharacterTab;
  final bool highContrastTheme;
  final String dynamicSchemeVariant;
  final bool logCharacterRuntimeChanges;
  final bool groupConsecutiveChatMessages;

  Color get seedColor => Color(seedColorValue);

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'seedColorValue': seedColorValue,
    'defaultDice': defaultDice,
    'compactLists': compactLists,
    'confirmBeforeRoll': confirmBeforeRoll,
    'defaultCreationMethod': defaultCreationMethod,
    'showCharacterSources': showCharacterSources,
    'showEncumbrance': showEncumbrance,
    'defaultCharacterTab': defaultCharacterTab,
    'highContrastTheme': highContrastTheme,
    'dynamicSchemeVariant': dynamicSchemeVariant,
    'logCharacterRuntimeChanges': logCharacterRuntimeChanges,
    'groupConsecutiveChatMessages': groupConsecutiveChatMessages,
  };

  AppPreferences copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
    String? defaultDice,
    bool? compactLists,
    bool? confirmBeforeRoll,
    String? defaultCreationMethod,
    bool? showCharacterSources,
    bool? showEncumbrance,
    String? defaultCharacterTab,
    bool? highContrastTheme,
    String? dynamicSchemeVariant,
    bool? logCharacterRuntimeChanges,
    bool? groupConsecutiveChatMessages,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      defaultDice: defaultDice ?? this.defaultDice,
      compactLists: compactLists ?? this.compactLists,
      confirmBeforeRoll: confirmBeforeRoll ?? this.confirmBeforeRoll,
      defaultCreationMethod:
          defaultCreationMethod ?? this.defaultCreationMethod,
      showCharacterSources: showCharacterSources ?? this.showCharacterSources,
      showEncumbrance: showEncumbrance ?? this.showEncumbrance,
      defaultCharacterTab: defaultCharacterTab ?? this.defaultCharacterTab,
      highContrastTheme: highContrastTheme ?? this.highContrastTheme,
      dynamicSchemeVariant: dynamicSchemeVariant ?? this.dynamicSchemeVariant,
      logCharacterRuntimeChanges:
          logCharacterRuntimeChanges ?? this.logCharacterRuntimeChanges,
      groupConsecutiveChatMessages:
          groupConsecutiveChatMessages ?? this.groupConsecutiveChatMessages,
    );
  }
}
