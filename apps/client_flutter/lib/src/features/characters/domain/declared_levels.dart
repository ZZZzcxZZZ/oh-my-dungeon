import '../../content/domain/content_entry.dart';
import '../../rules/domain/rule_profile.dart';
import 'character.dart';
import 'dnd5e_rules.dart';

/// 角色的`data.classIdentity.declaredLevels`读取器（契约 §3.12）。
///
/// 部分声明是一等功能：职业可以只声明 1–5 级，`Table` 允许短数组；高于最后声明
/// 等级沿用最后声明值，低于最早声明等级为"未声明"。界面由此判断"这个等级的内容
/// 是否被声明过"，**数值型未声明不得渲染成 0**。
///
/// 三种来源各有边界：
/// - [DeclaredLevels.fromCharacter]：角色持久化的声明范围（条目自身声明，任务 8 写入）；
/// - [DeclaredLevels.fromEntry]：条目自身声明的范围（资料库规则视图 / 导入预览用）；
/// - [DeclaredLevels.fromResolvedClassRules]：条目 ∪ 内置档案合并后**实际生效**的
///   范围（创建向导用：没有职业条目、只按展示名命中内置档案时也要给出真实范围）。
class DeclaredLevels {
  const DeclaredLevels({this.min = 1, this.max});

  /// 最低声明等级；缺省 1。
  final int min;

  /// 最高声明等级；`null` = 该职业**完全没有**等级声明。
  final int? max;

  /// 完全没有等级声明（`max == null`）。
  bool get isEmpty => max == null;

  /// 该等级是否落在声明范围内。
  bool covers(int level) {
    final maximum = max;
    return maximum != null && level >= min && level <= maximum;
  }

  /// 是否高于最后声明等级（§3.12：沿用最后声明值，仍可继续）。
  bool isBeyond(int level) {
    final maximum = max;
    return maximum != null && level > maximum;
  }

  /// 是否低于最早声明等级（§3.12：该等级未声明）。
  bool isBelow(int level) => max != null && level < min;

  /// 声明范围文案：`职业声明：1–5 级`；完全没有声明时给显式说明。
  String get rangeLabel =>
      isEmpty ? '该职业未声明任何等级内容' : '职业声明：$min–$max 级';

  /// 高于最后声明等级时的补充说明（信息级，不是错误）。
  String get beyondLabel => isEmpty
      ? rangeLabel
      : '该职业未声明 ${max! + 1} 级以上内容，你仍可继续（数值按未声明处理）';

  /// 低于最早声明等级时的补充说明（信息级，不是错误）。
  String get belowLabel =>
      isEmpty ? rangeLabel : '该职业未声明 $min 级以下内容，你仍可继续（数值按未声明处理）';

  /// 指定等级的"未声明"补充说明；已覆盖或完全没有声明时返回 `null`
  /// （完全没有声明时 [rangeLabel] 已经说清了）。
  String? detailLabel(int level) {
    if (isEmpty || covers(level)) return null;
    return isBeyond(level) ? beyondLabel : belowLabel;
  }

  /// 从角色持久化的 `data.classIdentity.declaredLevels` 读取。
  ///
  /// 缺省（没有 `classIdentity` / 没有 `declaredLevels` / `min` 不是数字）为
  /// `min = 1, max = null`：**完全没有等级声明**。
  static DeclaredLevels fromCharacter(CharacterSheet character) {
    final identity = character.dataMap['classIdentity'];
    final raw = identity is Map ? identity['declaredLevels'] : null;
    if (raw is! Map) return const DeclaredLevels();
    return _fromRaw(raw);
  }

  /// 条目自身声明的范围（`structured.classRules`；条目为空即完全没有声明）。
  static DeclaredLevels fromEntry(ContentEntry? entry) {
    if (entry == null) return const DeclaredLevels();
    final rules = Dnd5eRules.resolveClassRules(
      entryId: entry.id,
      classSummary: entry.name,
      structured: entry.structured,
    );
    return DeclaredLevels(
      min: rules.declaredMinLevel ?? 1,
      max: rules.declaredMaxLevel,
    );
  }

  /// 条目 ∪ 内置档案合并后实际生效的范围（创建向导的等级滑杆用）。
  static DeclaredLevels fromResolvedClassRules(ResolvedClassRules rules) {
    final maximums = <int>[
      ...?rules.spellcasting?.declaredMaxLevels,
      ...rules.resources
          .map((resource) => resource.declaredMaxLevel)
          .whereType<int>(),
    ];
    if (maximums.isEmpty) return const DeclaredLevels();
    final minimums = <int>[
      ...?rules.spellcasting?.declaredMinLevels,
      ...rules.resources
          .map((resource) => resource.declaredMinLevel)
          .whereType<int>(),
    ];
    return DeclaredLevels(
      min: minimums.isEmpty
          ? 1
          : minimums.reduce((a, b) => a < b ? a : b),
      max: maximums.reduce((a, b) => a > b ? a : b),
    );
  }

  static DeclaredLevels _fromRaw(Map<Object?, Object?> raw) {
    return DeclaredLevels(
      min: raw['min'] is num ? (raw['min']! as num).toInt() : 1,
      max: raw['max'] is num ? (raw['max']! as num).toInt() : null,
    );
  }
}
