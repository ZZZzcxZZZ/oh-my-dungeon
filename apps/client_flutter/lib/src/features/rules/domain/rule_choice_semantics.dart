import '../../content/domain/content_entry.dart';
import 'character_rule_definition.dart';
import 'rule_choice_resolver.dart';

/// 一个候选选项的**统一视图**：内联选项与条目候选在 UI/引擎里不再分叉。
///
/// - [entry] 非空 = 条目候选（选中后该条目进规则队列）；
/// - [entry] 为空 = 内联选项（选中后由 [RuleChoiceSemantics.grantsForSelection]
///   展开 grants）。
class RuleChoiceCandidate {
  const RuleChoiceCandidate({
    required this.id,
    required this.label,
    this.description,
    this.entry,
    this.grants = const <RuleGrantDefinition>[],
    this.data = const <String, Object?>{},
    this.requires = const <RuleRequiresDefinition>[],
  });

  final String id;
  final String label;
  final String? description;
  final ContentEntry? entry;
  final List<RuleGrantDefinition> grants;
  final Map<String, Object?> data;

  /// 内联选项自带的前置依赖（决策 D6；条目候选恒为空）。
  final List<RuleRequiresDefinition> requires;

  bool get isInline => entry == null;
}

/// 选中值规范化时发现的违规（契约 §3.10.3）。一个请求值最多记一条。
enum RuleChoiceViolation { notACandidate, notRepeatable, aboveMaximum }

/// [RuleChoiceSemantics.normalizeSelection] 的结果。
class RuleChoiceSelection {
  const RuleChoiceSelection({
    required this.selected,
    required this.invalidSelected,
    required this.violations,
  });

  /// 合法选中值，顺序 = 用户选择顺序（即 `build.choices` 的落库顺序）。
  final List<String> selected;

  /// 被拒绝的请求值，顺序 = 请求顺序。**不静默丢弃**：调用方据此报 pending。
  final List<String> invalidSelected;

  final Set<RuleChoiceViolation> violations;
}

/// 选择系统**纯函数语义层**：候选、选中值规范化、自动授予、前置条件、键解析。
///
/// **唯一实现点（目标态）**：本层目前只被测试调用；引擎与三处选择 UI（创建向导 /
/// 编辑器升级队列 / 独立升级页）的直接调用在**计划任务 3–6 迁移**，迁移完成后
/// 调用方不得再写第二套候选 / 规范化 / 授予判断。
///
/// 唯一实现点约定（规格 §3.10；本计划的「唯一实现点总表」）：
/// - 候选枚举只有 [candidatesFor] 一处（内联候选固定排在条目候选之前；条目候选
///   内部顺序由 `RuleChoiceResolver.optionsFor` 决定，其 `List.sort` 非稳定排序，
///   本层不承诺条目之间的顺序稳定）；
///   条目侧**复用** `RuleChoiceResolver.optionsFor`，不复制过滤逻辑；
/// - 选中值合法性只有 [normalizeSelection] 一处；
/// - 字符串简写自动授予只有 [autoGrantsFor] 一处（导入器与运行时共用）；
/// - `requires` 判定只有 [requiresSatisfied] 一处，作用域链只有
///   [scopeEntryIdsFor] 一处（选项级 requires 经 [candidateRequiresSatisfied]
///   转调，不另写判据）。
/// 任何调用方都不得再写"条目 vs 内联"或"重复 vs 非重复"的第二套判断。
abstract final class RuleChoiceSemantics {
  /// 候选枚举：内联 `options`（声明顺序）在前，条目候选（
  /// `RuleChoiceResolver.optionsFor` 的过滤与排序）在后。
  ///
  /// **唯一实现点（目标态）**：引擎与三处 UI 的直接调用在计划任务 3–6 迁移。
  ///
  /// 末尾按 id 去重：内联候选与 `optionTags` / `optionEntryIds` 派生的条目候选同
  /// id 时**保留内联候选**（内联 `grants` 是作者显式写的），丢弃同 id 的条目候选；
  /// 否则 [grantsForSelection] 的 id→候选 map 会被排在后面的条目候选覆盖，内联
  /// grants 被静默丢弃。重复声明的内联 id 仍按声明顺序原样保留（由导入期
  /// `duplicateOptionId` 报错），不在这里折叠，以免改变既有选择语义。
  static List<RuleChoiceCandidate> candidatesFor(
    RuleChoiceDefinition definition, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
  }) {
    final inline = definition.options
        .map(
          (option) => RuleChoiceCandidate(
            id: option.id,
            label: option.label,
            description: option.description,
            grants: option.grants,
            data: option.data,
            requires: option.requires,
          ),
        )
        .toList(growable: false);
    final entryOptions = RuleChoiceResolver(entries: entries)
        .optionsFor(definition, sourceEntryId: sourceEntryId)
        .map(
          (entry) => RuleChoiceCandidate(
            id: entry.id,
            label: entry.name,
            entry: entry,
          ),
        )
        .toList(growable: false);
    final inlineIds = <String>{for (final candidate in inline) candidate.id};
    return List<RuleChoiceCandidate>.unmodifiable([
      ...inline,
      ...entryOptions.where((candidate) => !inlineIds.contains(candidate.id)),
    ]);
  }

  /// 把请求的选中值规范化为"合法选中 + 被拒值 + 违规类型"。
  ///
  /// **唯一实现点（目标态）**：引擎与三处 UI 的直接调用在计划任务 3–6 迁移。
  ///
  /// 规则（顺序即用户选择顺序，**不排序**）：
  /// 1. 不在候选集（[candidatesFor]）里的值 → `notACandidate`；
  /// 2. `repeatable == false` 时同一 id 的第二次出现 → `notRepeatable`；
  /// 3. 超出上限（[effectiveMaximum] 优先于 `definition.maximum`）→
  ///    `aboveMaximum`。
  ///
  /// 注意：本方法**不**看 `requires`。前置不满足的已选值仍留在 [RuleChoiceSelection.selected]，
  /// 由引擎放进 pending（§3.10.3-5：不静默丢弃）。
  static RuleChoiceSelection normalizeSelection(
    RuleChoiceDefinition definition,
    List<String> requested, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
    int? effectiveMaximum,
  }) {
    final candidateIds = candidatesFor(
      definition,
      entries: entries,
      sourceEntryId: sourceEntryId,
    ).map((candidate) => candidate.id).toSet();
    final maximum = effectiveMaximum ?? definition.maximum;
    final selected = <String>[];
    final invalid = <String>[];
    final violations = <RuleChoiceViolation>{};
    for (final id in requested) {
      if (!candidateIds.contains(id)) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.notACandidate);
        continue;
      }
      if (!definition.repeatable && selected.contains(id)) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.notRepeatable);
        continue;
      }
      if (selected.length >= maximum) {
        invalid.add(id);
        violations.add(RuleChoiceViolation.aboveMaximum);
        continue;
      }
      selected.add(id);
    }
    return RuleChoiceSelection(
      selected: List<String>.unmodifiable(selected),
      invalidSelected: List<String>.unmodifiable(invalid),
      violations: Set<RuleChoiceViolation>.unmodifiable(violations),
    );
  }

  /// 字符串简写自动授予（契约 §3.10.2 表）。
  ///
  /// 返回值三态：
  /// - 非空列表 = 该选项自动授予的 grants；
  /// - 空列表 = "只记录选择、不产出 grants"的值类型
  ///   （`damageType` / `weaponMastery` / `value` / `language`）；
  /// - `null` = **无法推断**（条目类型的字符串元素，或 `ability` 显式写了非正整数
  ///   的 `data['value']`），导入期据此报 `invalidAutoGrant`（决策 D1）。
  ///
  /// `ability` 的加值取 `data['value']`（决策 D2）：**缺省**（无 `value` 键或值为
  /// `null`）为 1（规格 §3.10.2 `<choice.value ?? 1>`）；显式写了但不是正整数时
  /// **不猜**，返回 `null` 交给导入期报 `invalidAutoGrant`。
  static List<RuleGrantDefinition>? autoGrantsFor({
    required String optionType,
    required String optionId,
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    switch (optionType) {
      case 'skill':
        return [
          RuleGrantDefinition(
            id: 'skill:$optionId',
            kind: RuleGrantKind.proficiency,
            label: optionId,
            target: 'skill:$optionId',
          ),
        ];
      case 'ability':
        final raw = data['value'];
        final int value;
        if (raw == null) {
          value = 1;
        } else if (raw is num && raw.isFinite && raw > 0 && raw == raw.toInt()) {
          value = raw.toInt();
        } else {
          // 显式写了 0 / 负数 / 非数字 / 非整数：不静默改写成 1，走"无法推断"。
          return null;
        }
        return [
          RuleGrantDefinition(
            id: 'ability:$optionId',
            kind: RuleGrantKind.ability,
            label: optionId,
            target: optionId,
            value: value,
          ),
        ];
      case 'language':
      case 'damageType':
      case 'weaponMastery':
      case 'value':
        return const <RuleGrantDefinition>[];
      default:
        // `kAutoGrantOptionTypes` 的成员必须在这里都有显式分支：本 default
        // 只承接"条目类型"（决策 D1），不承接值类型。
        return null;
    }
  }

  /// 选中值的 grants 展开：内联选项**显式** `grants` 优先；没有显式 grants 时
  /// 退回 [autoGrantsFor]。重复选中按次数重复展开（`repeatable` 的结算依据）。
  ///
  /// 条目候选**不**在这里展开自身 grants（它由规则队列/ledger 承担）；非候选值
  /// 一律忽略。返回空列表表示"这些选择不产出 grants"。
  static List<RuleGrantDefinition> grantsForSelection(
    RuleChoiceDefinition definition,
    List<String> selected, {
    required Map<String, ContentEntry> entries,
    String? sourceEntryId,
  }) {
    final candidates = {
      for (final candidate in candidatesFor(
        definition,
        entries: entries,
        sourceEntryId: sourceEntryId,
      ))
        candidate.id: candidate,
    };
    final result = <RuleGrantDefinition>[];
    for (final id in selected) {
      final candidate = candidates[id];
      if (candidate == null) continue;
      if (candidate.grants.isNotEmpty) {
        result.addAll(candidate.grants);
        continue;
      }
      final auto = autoGrantsFor(
        optionType: definition.optionType,
        optionId: candidate.id,
        data: candidate.data,
      );
      if (auto != null) result.addAll(auto);
    }
    return List<RuleGrantDefinition>.unmodifiable(result);
  }

  /// `requires` 是否全部满足（AND；空列表恒满足）。
  ///
  /// - `{choice, option?}`：在 [scopeEntryIdsFor] 作用域内、key 为
  ///   `<条目 id>#<choiceId>[#<等级>]` 的选中值集合必须包含 `option`（未写
  ///   `option` 时只要有任意选中值即可）。`option` 匹配**选中值**，内联选项 id
  ///   与条目 id 都算（决策 D5）。
  /// - `{ability, minimum}`：读入参 `abilities`（**基础属性**，决策 D4）；属性键
  ///   缺失 = 未记录 → 不满足（不猜成 10 或 0）。
  ///
  /// 作用域链的遍历只有 [scopeEntryIdsFor] 一处，导入器与运行期共用。
  static bool requiresSatisfied(
    List<RuleRequiresDefinition> requires, {
    required String sourceEntryId,
    required Map<String, List<String>> selectedByKey,
    required Map<String, int> abilities,
    required Map<String, ContentEntry> entries,
  }) {
    if (requires.isEmpty) return true;
    final scope = scopeEntryIdsFor(sourceEntryId, entries);
    for (final requirement in requires) {
      if (requirement.isAbilityForm) {
        final score = abilities[requirement.ability];
        final minimum = requirement.minimum;
        if (score == null || minimum == null || score < minimum) return false;
        continue;
      }
      final choiceId = requirement.choice;
      if (choiceId == null) return false;
      final chosen = _selectedOptions(
        selectedByKey,
        scope: scope,
        choiceId: choiceId,
      );
      if (chosen.isEmpty) return false;
      final option = requirement.option;
      if (option != null && !chosen.contains(option)) return false;
    }
    return true;
  }

  /// 选项级 `requires`（`options[].requires`，决策 D6）是否满足。
  ///
  /// 薄封装：判定本体只有 [requiresSatisfied] 一处，本方法只负责把候选自带的
  /// requires 传进去。UI/引擎决定"隐藏该选项"时只调它，不重写判定。
  static bool candidateRequiresSatisfied(
    RuleChoiceCandidate candidate, {
    required String sourceEntryId,
    required Map<String, List<String>> selectedByKey,
    required Map<String, int> abilities,
    required Map<String, ContentEntry> entries,
  }) {
    return requiresSatisfied(
      candidate.requires,
      sourceEntryId: sourceEntryId,
      selectedByKey: selectedByKey,
      abilities: abilities,
      entries: entries,
    );
  }

  /// 选择键 `<entryId>#<choiceId>[#<level>]` → 定义解析。
  ///
  /// `entryId` 不在 [entries] 里、键缺少 `#`、或该条目没有这个 choice id 时返回
  /// `null`。定义来源为 `rules.choices` ∪ `rules.progression[].choices`；等级段
  /// 只作为返回值带出，不做等级过滤（调用方按需判断）。
  static ({RuleChoiceDefinition definition, String sourceEntryId, int? level})?
  definitionForKey(String key, {required Map<String, ContentEntry> entries}) {
    final parts = key.split('#');
    if (parts.length < 2) return null;
    final entry = entries[parts[0]];
    if (entry == null) return null;
    final level = parts.length >= 3 ? int.tryParse(parts[2]) : null;
    for (final definition in _definitionsOf(entry)) {
      if (definition.id == parts[1]) {
        return (
          definition: definition,
          sourceEntryId: entry.id,
          level: level,
        );
      }
    }
    return null;
  }

  /// `<sourceEntryId>` 及其沿 `featureOf` / `subclassOf` 向上找到的祖先（§3.11 A4）。
  ///
  /// 公开实现点：运行期 [requiresSatisfied] 与导入期 `requires` 引用校验都调它，
  /// 导入器**不得**自己再写一遍关系链遍历。
  ///
  /// 返回**不可变副本**（`Set.unmodifiable`，调用方只读，不提供可变更改入口）；
  /// 迭代顺序 = 从 `sourceEntryId` 出发的**发现顺序**（BFS：自身 → 一跳祖先 →
  /// 两跳祖先…），调用方不应依赖更具体的顺序。
  static Set<String> scopeEntryIdsFor(
    String sourceEntryId,
    Map<String, ContentEntry> entries,
  ) {
    final scope = <String>{sourceEntryId};
    var pending = <String>{sourceEntryId};
    while (pending.isNotEmpty) {
      final next = <String>{};
      for (final id in pending) {
        final entry = entries[id];
        if (entry == null) continue;
        for (final relation in entry.relations) {
          if (relation.type != 'featureOf' && relation.type != 'subclassOf') {
            continue;
          }
          if (scope.add(relation.targetId)) next.add(relation.targetId);
        }
      }
      pending = next;
    }
    return Set<String>.unmodifiable(scope);
  }

  static List<String> _selectedOptions(
    Map<String, List<String>> selectedByKey, {
    required Set<String> scope,
    required String choiceId,
  }) {
    final values = <String>[];
    selectedByKey.forEach((key, selected) {
      final parts = key.split('#');
      if (parts.length < 2) return;
      if (!scope.contains(parts[0]) || parts[1] != choiceId) return;
      for (final value in selected) {
        if (!values.contains(value)) values.add(value);
      }
    });
    return values;
  }

  static Iterable<RuleChoiceDefinition> _definitionsOf(
    ContentEntry entry,
  ) sync* {
    final rules = entry.rules;
    if (rules == null) return;
    yield* rules.choices;
    for (final step in rules.progression) {
      yield* step.choices;
    }
  }
}
