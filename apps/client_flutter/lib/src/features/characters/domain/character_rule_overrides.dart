// S3 决策 D6：角色对"跨包规则覆盖"的选择的**唯一**读取 / 写入实现。
import 'character.dart';

/// 角色数据 `data.ruleOverrides` 的唯一读写实现（契约 S3、决策 D6）。
///
/// - [disabledOriginIds]：用户显式关掉的覆盖来源（**条目 id 或包 id 命中都算**），
///   解析器据此把该来源从合并链里剔除，回退更低 tier（"关闭覆盖回退内置"）；
/// - [pinned]：用户为**某一列**显式选定的来源（键 = `RuleFieldPath` 的列路径，
///   值 = originId）。pin 是显式选择，语义上高于 priority。
///
/// 页面**不得**直接读写 `dataMap['ruleOverrides']`：形状归一化（去重、排序、
/// 坏数据降级）只在这里一份，否则同一份用户选择会有第二种解释。
class CharacterRuleOverrides {
  const CharacterRuleOverrides({
    this.disabledOriginIds = const <String>{},
    this.pinned = const <String, String>{},
  });

  static const empty = CharacterRuleOverrides();

  factory CharacterRuleOverrides.fromCharacter(CharacterSheet character) {
    final raw = character.dataMap['ruleOverrides'];
    return raw is Map
        ? CharacterRuleOverrides.fromJson(Map<String, Object?>.from(raw))
        : empty;
  }

  factory CharacterRuleOverrides.fromJson(Map<String, Object?> json) =>
      CharacterRuleOverrides(
        disabledOriginIds: _stringSet(json['disabledOriginIds']),
        pinned: _stringMap(json['pinned']),
      );

  final Set<String> disabledOriginIds;
  final Map<String, String> pinned;

  /// 持久化形状：来源 id 去重后排序、pin 按列路径排序——同样输入写出同样的 JSON，
  /// diff 与测试稳定（唯一实现）。
  Map<String, Object?> toData() => <String, Object?>{
    'disabledOriginIds': disabledOriginIds.toList()..sort(),
    'pinned': <String, String>{
      for (final key in pinned.keys.toList()..sort()) key: pinned[key]!,
    },
  };
}

/// 坏数据降级为"没有禁用"（不猜一个来源 id）。
Set<String> _stringSet(Object? raw) => raw is List
    ? <String>{
        for (final value in raw)
          if (value is String && value.trim().isNotEmpty) value.trim(),
      }
    : const <String>{};

/// 坏数据降级为"没有 pin"（不猜一个来源 id）。
Map<String, String> _stringMap(Object? raw) => raw is Map
    ? <String, String>{
        for (final entry in raw.entries)
          if (entry.value is String &&
              '${entry.value}'.trim().isNotEmpty &&
              '${entry.key}'.trim().isNotEmpty)
            '${entry.key}'.trim(): '${entry.value}'.trim(),
      }
    : const <String, String>{};
