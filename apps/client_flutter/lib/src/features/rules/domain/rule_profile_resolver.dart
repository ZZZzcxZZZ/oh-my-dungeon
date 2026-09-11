// 内置档案解析 + "条目声明 ∪ 档案"的字段级合并（§3.6、§3.7、§3.8）。
//
// 只有两级优先级：内置档案（tier 0）< 角色所用条目的声明（tier 100）。
// 不做全局条目扫描、没有 priority 字段（§3.8）；未声明即不猜（§3.6 第 3 步）。
//
// 档案解析是 fail-fast（§3.1）：`abilities` / `skills` 是校验参照表，必须由档案
// **显式声明**；`progressions` 只允许 `kProgressionFields` 里的键。任何一处缺失、
// 为空或类型错误都报 error 并让 `profile == null`，绝不伪造占位值兜底。
import 'class_rule_set.dart';
import 'rule_diagnostic.dart';
import 'rule_profile.dart';
import 'rule_values.dart';

/// 内置档案解析结果。出现 error 时 [profile] 为 null（整包阻断，§4.4）。
class RuleProfileResolution {
  const RuleProfileResolution({
    required this.profile,
    required this.diagnostics,
  });

  final RuleProfile? profile;
  final List<RuleDiagnostic> diagnostics;

  List<RuleDiagnostic> get errors => diagnostics
      .where((d) => d.severity == RuleSeverity.error)
      .toList(growable: false);

  List<RuleDiagnostic> get warnings => diagnostics
      .where((d) => d.severity == RuleSeverity.warning)
      .toList(growable: false);
}

abstract final class RuleProfileResolver {
  /// 解析内置档案（§3.1）。只做编排：逐节解析 + 原型引用校验 + 整包阻断。
  static RuleProfileResolution resolveBuiltin(Map<String, Object?> raw) {
    final diagnostics = <RuleDiagnostic>[];
    final abilities = _parseAbilities(raw, diagnostics);
    final skills = _parseSkills(raw, diagnostics);
    final progressions = _parseProgressions(raw, diagnostics);
    final classes = _parseClasses(raw, abilities, diagnostics);
    _validateArchetypes(classes, progressions, diagnostics);

    if (diagnostics.any((d) => d.severity == RuleSeverity.error)) {
      return RuleProfileResolution(profile: null, diagnostics: diagnostics);
    }
    return RuleProfileResolution(
      profile: RuleProfile(
        abilities: abilities,
        skills: skills,
        progressions: progressions,
        classes: classes,
      ),
      diagnostics: diagnostics,
    );
  }

  /// 参照清单之一（§3.1）：必须显式声明为非空字符串数组。
  static Set<String> _parseAbilities(
    Map<String, Object?> raw,
    List<RuleDiagnostic> diagnostics,
  ) {
    final rawAbilities = raw['abilities'];
    if (rawAbilities is! List || rawAbilities.isEmpty) {
      _invalidTable(diagnostics, r'$.abilities', 'abilities 必须显式声明为非空数组');
      return const {};
    }
    final abilities = <String>{};
    var failed = false;
    for (final item in rawAbilities) {
      if (item is! String || item.trim().isEmpty) {
        _invalidTable(diagnostics, r'$.abilities', '属性键必须是非空字符串，实际为 $item');
        failed = true;
        continue;
      }
      abilities.add(item.trim().toLowerCase());
    }
    // 只要有一项不合法，整份参照清单就不可用：返回空集让下游退回标准清单校验，
    // 避免"坏了一项 → 每个豁免键都再报一次未知属性"的连锁噪音（profile 必为 null）。
    return failed ? const {} : abilities;
  }

  /// 参照清单之二（§3.1）：必须显式声明为非空数组，每项 `{name, ability}`。
  /// **不得**伪造占位（把技能属性写成空串会让消费方分不清空串与合法属性键）。
  static Map<String, String> _parseSkills(
    Map<String, Object?> raw,
    List<RuleDiagnostic> diagnostics,
  ) {
    final rawSkills = raw['skills'];
    if (rawSkills is! List || rawSkills.isEmpty) {
      _invalidTable(diagnostics, r'$.skills', 'skills 必须显式声明为非空数组');
      return const {};
    }
    final skills = <String, String>{};
    for (var index = 0; index < rawSkills.length; index++) {
      final item = rawSkills[index];
      final path = '\$.skills[$index]';
      if (item is! Map) {
        _invalidTable(diagnostics, path, '技能项必须是 {name, ability} 对象');
        continue;
      }
      final name = item['name'];
      final ability = item['ability'];
      if (name is! String ||
          name.trim().isEmpty ||
          ability is! String ||
          ability.trim().isEmpty) {
        _invalidTable(diagnostics, path, '技能项必须同时声明非空的 name 与 ability');
        continue;
      }
      skills[name.trim()] = ability.trim().toLowerCase();
    }
    return skills;
  }

  /// 解析 `progressions`（§3.1）：原型只承载 [kProgressionFields] 里的键，
  /// 出现其它键（典型是把 `prepared` / `cantrips` 塞回原型）报 `unknownField`。
  static Map<String, ClassProgression> _parseProgressions(
    Map<String, Object?> raw,
    List<RuleDiagnostic> diagnostics,
  ) {
    final progressions = <String, ClassProgression>{};
    final rawProgressions = raw['progressions'];
    if (rawProgressions is! Map) {
      _invalidTable(diagnostics, r'$.progressions', 'progressions 必须是对象');
      return progressions;
    }
    rawProgressions.forEach((key, value) {
      final name = '$key';
      final path = r'$.progressions.' + name;
      if (value is! Map) {
        _invalidTable(diagnostics, path, '原型必须是对象');
        return;
      }
      final map = Map<String, Object?>.from(value);
      // 顺序约定：进入子结构前先报该层未知键（见 class_rule_set.dart 文件头）。
      for (final rawKey in map.keys) {
        if (!kProgressionFields.contains(rawKey)) {
          _unknownField(diagnostics, '$path.$rawKey', rawKey);
        }
      }
      final slots = SlotTable.tryParse(map['slots']);
      // 空数组 / 空对象是"该原型没有声明任何档位"的合法写法（§3.1 的 `none`
      // 就是 `{"slots": []}`），不是错误；只有写了内容却解析不出表才报错。
      if (map['slots'] != null &&
          !_isEmptyTable(map['slots']) &&
          slots == null) {
        _invalidTable(
          diagnostics,
          '$path.slots',
          'slots 必须是 20 项数组或稀疏 {"等级": 值}',
        );
      }
      progressions[name] = ClassProgression(
        name: name,
        minimumLevel: _parseMinimumLevel(map, path, diagnostics),
        slots: slots,
        slotLevel: _progressionTable(map, 'slotLevel', path, diagnostics),
        maximumSpellLevel: _progressionTable(
          map,
          'maximumSpellLevel',
          path,
          diagnostics,
        ),
      );
    });
    return progressions;
  }

  /// 原型里的 `IntTable` 字段；写了内容却解析不出表 → `invalidTable`（不静默 return）。
  static IntTable? _progressionTable(
    Map<String, Object?> map,
    String key,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    final table = IntTable.tryParse(map[key]);
    if (map[key] != null && table == null) {
      _invalidTable(diagnostics, '$path.$key', '$key 必须是 20 项数组或稀疏 {"等级": 值}');
    }
    return table;
  }

  /// 原型的 `minimumLevel`：省略取默认 1，写了就必须是 1..20 的整数。
  /// 非整数不得被静默吞成 1——那会让 3 级才解锁的原型在 1 级就生效。
  static int _parseMinimumLevel(
    Map<String, Object?> map,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    if (!map.containsKey('minimumLevel')) return 1;
    final value = map['minimumLevel'];
    if (value is! int || value < 1 || value > 20) {
      _invalidTable(
        diagnostics,
        '$path.minimumLevel',
        'minimumLevel 必须是 1..20 的整数',
      );
      return 1;
    }
    return value;
  }

  /// 解析 `classes`（§3.2）：键是规范英文 slug，值交给 [ClassRuleSet.parse]。
  static Map<String, ClassRuleSet> _parseClasses(
    Map<String, Object?> raw,
    Set<String> abilities,
    List<RuleDiagnostic> diagnostics,
  ) {
    final classes = <String, ClassRuleSet>{};
    final rawClasses = raw['classes'];
    if (rawClasses is! Map) {
      _invalidTable(diagnostics, r'$.classes', 'classes 必须是对象');
      return classes;
    }
    rawClasses.forEach((key, value) {
      final slug = '$key'.trim().toLowerCase();
      final path = r'$.classes.' + slug;
      if (value is! Map) {
        _invalidTable(diagnostics, path, '职业规则必须是对象');
        return;
      }
      classes[slug] = ClassRuleSet.parse(
        Map<String, Object?>.from(value),
        path: path,
        diagnostics: diagnostics,
        // abilities 缺失本身已经报了 invalidTable（profile 必为 null）；这里给它
        // 标准清单只为避免"每个豁免键都再报一次未知属性"的连锁噪音。
        abilities: abilities.isEmpty ? kDefaultAbilities : abilities,
      );
    });
    return classes;
  }

  /// 原型存在性校验（§3.3）：引用不存在的原型必须报 error，而不是静默无法术位。
  static void _validateArchetypes(
    Map<String, ClassRuleSet> classes,
    Map<String, ClassProgression> progressions,
    List<RuleDiagnostic> diagnostics,
  ) {
    for (final entry in classes.entries) {
      final archetype = entry.value.spellcasting?.archetype;
      if (archetype != null && !progressions.containsKey(archetype)) {
        diagnostics.add(
          RuleDiagnostic(
            path: '\$.classes.${entry.key}.spellcasting.archetype',
            severity: RuleSeverity.error,
            code: 'unknownArchetype',
            message: '未知原型 "$archetype"',
          ),
        );
      }
    }
  }

  /// 条目声明 ∪ 档案（条目优先，**字段级**，§3.6、§3.7、§3.8）。
  static ResolvedClassRules resolveClassRules({
    required RuleProfile profile,
    required String slug,
    required ClassRuleSet? entryRules,
    String? entryId,
  }) {
    final fromArchive = profile.classRules(slug);
    final entryOrigin = entryId ?? '<entry>';
    final sources = <String, RuleFieldSource>{};

    final spellcasting = _mergeField<ClassSpellcasting>(
      field: 'spellcasting',
      entryRules: entryRules,
      fromArchive: fromArchive,
      entryOrigin: entryOrigin,
      sources: sources,
      read: (rules) => rules.spellcasting,
    );
    return ResolvedClassRules(
      hitDie: _mergeField<int>(
        field: 'hitDie',
        entryRules: entryRules,
        fromArchive: fromArchive,
        entryOrigin: entryOrigin,
        sources: sources,
        read: (rules) => rules.hitDie,
      ),
      savingThrowAbilities:
          _mergeField<Set<String>>(
            field: 'savingThrowAbilities',
            entryRules: entryRules,
            fromArchive: fromArchive,
            entryOrigin: entryOrigin,
            sources: sources,
            read: (rules) => rules.savingThrowAbilities,
          ) ??
          const {},
      spellcasting: spellcasting,
      resources:
          _mergeField<List<ClassResourceRule>>(
            field: 'resources',
            entryRules: entryRules,
            fromArchive: fromArchive,
            entryOrigin: entryOrigin,
            sources: sources,
            read: (rules) => rules.resources,
          ) ??
          const [],
      archetype: profile.progression(spellcasting?.archetype),
      fieldSources: sources,
      declaredMaxLevel: entryRules?.declaredMaxLevel,
      declaredMinLevel: entryRules?.declaredMinLevel,
    );
  }

  /// 单字段的两级取值：只有该侧**显式声明过**这个字段才取它的值，未声明就回退；
  /// 两侧都没声明则保持"未声明"（null），绝不按名字相近回退（§3.6）。
  ///
  /// 档案没声明过的字段不记来源：[ClassRuleSet] 的集合字段默认是空集合/空表，
  /// 不能把"默认值"当成"档案补齐"，否则来源记录会凭空多出字段（§3.7）。
  static T? _mergeField<T>({
    required String field,
    required ClassRuleSet? entryRules,
    required ClassRuleSet? fromArchive,
    required String entryOrigin,
    required Map<String, RuleFieldSource> sources,
    required T? Function(ClassRuleSet) read,
  }) {
    if (entryRules != null && entryRules.declares(field)) {
      final fromEntry = read(entryRules);
      if (fromEntry != null) {
        sources[field] = RuleFieldSource(
          field: field,
          originId: entryOrigin,
          tier: kEntryTier,
        );
        return fromEntry;
      }
    }
    if (fromArchive != null && fromArchive.declares(field)) {
      final fromBuiltin = read(fromArchive);
      if (fromBuiltin != null) {
        sources[field] = RuleFieldSource(
          field: field,
          originId: kBuiltinOriginId,
          tier: kBuiltinTier,
        );
        return fromBuiltin;
      }
    }
    return null;
  }
}

/// 档案形状/类型错误一律 error（§3.1、§5.2）。
void _invalidTable(List<RuleDiagnostic> out, String path, String message) =>
    out.add(
      RuleDiagnostic(
        path: path,
        severity: RuleSeverity.error,
        code: 'invalidTable',
        message: message,
      ),
    );

/// 白名单之外的键（§3.1）：解析期即拦，不留给测试兜底。
void _unknownField(List<RuleDiagnostic> out, String path, String name) =>
    out.add(
      RuleDiagnostic(
        path: path,
        severity: RuleSeverity.error,
        code: 'unknownField',
        message: '未知字段 $name',
      ),
    );

/// 空数组 / 空对象 = 没有声明任何档位（§3.1 的 `none` 原型就是 `[]`），不是错误。
bool _isEmptyTable(Object? raw) =>
    (raw is List && raw.isEmpty) || (raw is Map && raw.isEmpty);
