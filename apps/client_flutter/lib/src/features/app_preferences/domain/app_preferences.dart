import 'package:flutter/material.dart';

class AppPreferences {
  const AppPreferences({
    required this.themeMode,
    required this.seedColorValue,
    required this.defaultDice,
    required this.compactLists,
    required this.confirmBeforeRoll,
    required this.showCharacterSources,
    required this.defaultCharacterTab,
    required this.highContrastTheme,
    required this.dynamicSchemeVariant,
    required this.logCharacterRuntimeChanges,
    required this.groupConsecutiveChatMessages,
    required this.defaultRollMode,
    required this.quickDicePresets,
    required this.messageDensity,
    required this.fontScale,
    required this.hpWarningThreshold,
    this.returnToChatAfterRoll = true,
  });

  static const defaults = AppPreferences(
    themeMode: ThemeMode.system,
    seedColorValue: 0xff6750a4,
    defaultDice: '1d20',
    compactLists: false,
    confirmBeforeRoll: false,
    showCharacterSources: true,
    defaultCharacterTab: 'overview',
    highContrastTheme: false,
    dynamicSchemeVariant: 'tonalSpot',
    logCharacterRuntimeChanges: true,
    groupConsecutiveChatMessages: true,
    defaultRollMode: 'normal',
    quickDicePresets: <String>[],
    messageDensity: 'standard',
    fontScale: 'system',
    hpWarningThreshold: 0.3,
    returnToChatAfterRoll: true,
  );

  final ThemeMode themeMode;
  final int seedColorValue;
  final String defaultDice;
  final bool compactLists;
  final bool confirmBeforeRoll;
  final bool showCharacterSources;
  final String defaultCharacterTab;
  final bool highContrastTheme;
  final String dynamicSchemeVariant;
  final bool logCharacterRuntimeChanges;
  final bool groupConsecutiveChatMessages;

  /// Task 1.3 新增自定义项（原计划文档已归档删除，见 docs/archive/README.md 的清理记录）
  /// 默认掷骰模式：'normal' | 'advantage' | 'disadvantage'
  final String defaultRollMode;

  /// 快捷骰预设（最多 6 个），UI 由设置页维护；空列表表示使用内置默认。
  final List<String> quickDicePresets;

  /// 消息密度：'compact' | 'standard' | 'comfortable' — 控制 chat bubble padding 与字号
  final String messageDensity;

  /// 字体缩放：'system' | 'small' | 'medium' | 'large'
  final String fontScale;

  /// HP 警告阈值（0.0..1.0，默认 0.3），控制头像生命环颜色变化。
  final double hpWarningThreshold;
  final bool returnToChatAfterRoll;

  Color get seedColor => Color(seedColorValue);

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'seedColorValue': seedColorValue,
    'defaultDice': defaultDice,
    'compactLists': compactLists,
    'confirmBeforeRoll': confirmBeforeRoll,
    'showCharacterSources': showCharacterSources,
    'defaultCharacterTab': defaultCharacterTab,
    'highContrastTheme': highContrastTheme,
    'dynamicSchemeVariant': dynamicSchemeVariant,
    'logCharacterRuntimeChanges': logCharacterRuntimeChanges,
    'groupConsecutiveChatMessages': groupConsecutiveChatMessages,
    'defaultRollMode': defaultRollMode,
    'quickDicePresets': quickDicePresets,
    'messageDensity': messageDensity,
    'fontScale': fontScale,
    'hpWarningThreshold': hpWarningThreshold,
    'returnToChatAfterRoll': returnToChatAfterRoll,
  };

  AppPreferences copyWith({
    ThemeMode? themeMode,
    int? seedColorValue,
    String? defaultDice,
    bool? compactLists,
    bool? confirmBeforeRoll,
    bool? showCharacterSources,
    String? defaultCharacterTab,
    bool? highContrastTheme,
    String? dynamicSchemeVariant,
    bool? logCharacterRuntimeChanges,
    bool? groupConsecutiveChatMessages,
    String? defaultRollMode,
    List<String>? quickDicePresets,
    String? messageDensity,
    String? fontScale,
    double? hpWarningThreshold,
    bool? returnToChatAfterRoll,
  }) {
    return AppPreferences(
      themeMode: themeMode ?? this.themeMode,
      seedColorValue: seedColorValue ?? this.seedColorValue,
      defaultDice: defaultDice ?? this.defaultDice,
      compactLists: compactLists ?? this.compactLists,
      confirmBeforeRoll: confirmBeforeRoll ?? this.confirmBeforeRoll,
      showCharacterSources: showCharacterSources ?? this.showCharacterSources,
      defaultCharacterTab: defaultCharacterTab ?? this.defaultCharacterTab,
      highContrastTheme: highContrastTheme ?? this.highContrastTheme,
      dynamicSchemeVariant: dynamicSchemeVariant ?? this.dynamicSchemeVariant,
      logCharacterRuntimeChanges:
          logCharacterRuntimeChanges ?? this.logCharacterRuntimeChanges,
      groupConsecutiveChatMessages:
          groupConsecutiveChatMessages ?? this.groupConsecutiveChatMessages,
      defaultRollMode: defaultRollMode ?? this.defaultRollMode,
      quickDicePresets: quickDicePresets ?? this.quickDicePresets,
      messageDensity: messageDensity ?? this.messageDensity,
      fontScale: fontScale ?? this.fontScale,
      hpWarningThreshold: hpWarningThreshold ?? this.hpWarningThreshold,
      returnToChatAfterRoll:
          returnToChatAfterRoll ?? this.returnToChatAfterRoll,
    );
  }
}
