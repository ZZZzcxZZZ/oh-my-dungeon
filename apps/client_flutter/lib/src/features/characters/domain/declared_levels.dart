import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/rule_profile.dart';
import 'character.dart';
import 'dnd5e_rules.dart';

/// 角色等级上限（规则书 1–20）。滑杆的 `max` 与"未声明区间"文案共用这一个常量，
/// 避免各处硬编码 20 后各自漂移。
const kMaxCharacterLevel = 20;

/// 角色的`data.classIdentity.declaredLevels`读取器（契约 §3.12）。
///
/// 部分声明是一等功能：职业可以只声明 1–5 级，`Table` 允许短数组；高于最后声明
/// 等级沿用最后声明值，低于最早声明等级为"未声明"。界面由此判断"这个等级的内容
/// 是否被声明过"，**数值型未声明不得渲染成 0**。
///
/// 声明范围**只有一种口径**（§3.12）：[fromEntry] = 条目 `progression[].levels`
/// ∪ 条目各 `Table` 的范围 ∪ 内置档案同 slug 职业的相应范围。角色 Builder 写入、
/// 创建向导、资料库规则视图、导入预览全部走这一个入口，不得各自聚合。
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

  /// 滑杆下方的"已声明 / 未声明"区间文案（§3.12）：
  /// `已声明 1–5 级 · 6–20 级未声明`。
  ///
  /// 这是该文案的**唯一实现**：界面不得各自拼接区间字符串，也不得各自硬编码 20。
  String get declaredRangeCaption {
    final maximum = max;
    if (maximum == null) {
      return '该职业未声明任何等级 · 1–$kMaxCharacterLevel 级均按未声明处理';
    }
    return <String>[
      '已声明 $min–$maximum 级',
      if (min > 1) '1–${min - 1} 级未声明',
      if (maximum < kMaxCharacterLevel)
        '${maximum + 1}–$kMaxCharacterLevel 级未声明',
    ].join(' · ');
  }

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

  /// 声明范围的**唯一**口径（§3.12）：条目 `progression[].levels` ∪ 条目各表范围
  /// ∪ 内置档案同 slug 职业的相应范围。
  ///
  /// 这是写入（`RulesDrivenCharacterBuilder`）与全部界面（创建向导、资料库规则
  /// 视图、导入预览）共用的入口，任何地方都不许再自己拼。只有展示名、拿不到条目
  /// 的快速创建走 [fromResolvedClassRules]——同一个口径函数，只是没有 progression
  /// 可并。
  static DeclaredLevels fromEntry(ContentEntry? entry) {
    if (entry == null) return const DeclaredLevels();
    final rules = Dnd5eRules.resolveClassRules(
      entryId: entry.id,
      classSummary: entry.name,
      structured: entry.structured,
    );
    return fromResolvedClassRules(
      rules,
      progressionLevels: _progressionLevels(entry),
    );
  }

  /// 合并后各表范围（[ResolvedClassRules.declaredMinLevel] / `declaredMaxLevel`）
  /// ∪ [progressionLevels]（§3.12）。
  ///
  /// [fromEntry] 是它的唯一常规调用方（条目才有 `progression[].levels`）；只有
  /// 展示名、拿不到条目的路径（快速创建）直接调用它，口径仍然相同。
  static DeclaredLevels fromResolvedClassRules(
    ResolvedClassRules rules, {
    Iterable<int> progressionLevels = const <int>[],
  }) {
    final maximums = <int>[
      if (rules.declaredMaxLevel case final int max) max,
      ...progressionLevels,
    ];
    if (maximums.isEmpty) return const DeclaredLevels();
    final minimums = <int>[
      if (rules.declaredMinLevel case final int min) min,
      ...progressionLevels,
    ];
    return DeclaredLevels(
      min: minimums.reduce((a, b) => a < b ? a : b),
      max: maximums.reduce((a, b) => a > b ? a : b),
    );
  }

  /// 持久化形状 `data.classIdentity.declaredLevels`。
  ///
  /// 完全没有声明时 min / max 都是 null（与历史数据一致，[fromCharacter] 会把
  /// null 的 min 读回 1），而不是把"未声明"写成 0 或 1。
  Map<String, Object?> toData() => <String, Object?>{
    'min': isEmpty ? null : min,
    'max': max,
  };

  /// `entry.progression[].levels`。只有 `class` 条目算"职业声明"：种族 / 背景的
  /// 1 级步骤不是职业等级区间，不得让资料库视图凭空出现职业声明条。
  static Iterable<int> _progressionLevels(ContentEntry entry) sync* {
    if (entry.type != 'class') return;
    final progression =
        entry.rules?.progression ?? const <RuleProgressionDefinition>[];
    for (final step in progression) {
      yield* step.levels;
    }
  }

  static DeclaredLevels _fromRaw(Map<Object?, Object?> raw) {
    return DeclaredLevels(
      min: raw['min'] is num ? (raw['min']! as num).toInt() : 1,
      max: raw['max'] is num ? (raw['max']! as num).toInt() : null,
    );
  }
}
