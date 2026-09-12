// 内置档案解析 + "条目声明 ∪ 档案"的字段级合并（§3.6、§3.7、§3.8）。
//
// 只有两级优先级：内置档案（tier 0）< 角色所用条目的声明（tier 100）。
// 不做全局条目扫描、没有 priority 字段（§3.8）；未声明即不猜（§3.6 第 3 步）。
//
// 档案解析是 fail-fast（§3.1）：`abilities` / `skills` 是校验参照表，必须由档案
// **显式声明**；`progressions` 只允许 `kProgressionFields` 里的键。任何一处缺失、
// 为空或类型错误都报 error 并让 `profile == null`，绝不伪造占位值兜底。
//
// 原型 `slots` 的"模板压缩编码"是**只在内置档案里使用**的写法（§3.1），本文件是
// 契约里唯一的展开点：展开后运行期只有 `{环阶: 数量}` 一种形状。
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
    final aliases = _parseClassAliases(raw, classes, diagnostics);
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
        aliases: aliases,
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
      final slots = _parseSlots(map, name, path, diagnostics);
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

  /// 解析原型的 `slots`，并在**契约里唯一的展开点**把内置档案的模板压缩编码
  /// （§3.1）展开成运行期统一的 `{环阶: 数量}`，再交给 [SlotTable]。
  ///
  /// 除压缩编码外的写法（稀疏 `{"等级": {环阶:数量}}`、20 项 `{环阶:数量}` 数组）
  /// 原样交给 [SlotTable] 判定，解析器不额外认识第二种形状。空数组 / 空对象是
  /// "该原型没有声明任何档位"的合法写法（§3.1 的 `none` 就是 `{"slots": []}`），
  /// 不是错误；只有写了内容却解析不出表才报错。
  static SlotTable? _parseSlots(
    Map<String, Object?> map,
    String name,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    final raw = map['slots'];
    if (raw == null || _isEmptyTable(raw)) return null;
    Object? normalized = raw;
    if (_isCompressedSlots(raw)) {
      final rows = raw as List<Object?>;
      // `slotLevel` 只有 pact 原型会写（§3.1、§3.3），原型名 `pact` 是同一回事；
      // 两者取其一即按"每级一个环阶计数"展开。
      final isPact = name == kPactArchetype || map.containsKey('slotLevel');
      if (isPact) {
        final slotLevels = IntTable.tryParse(map['slotLevel']);
        if (slotLevels == null) {
          // 缺 `slotLevel`：环阶无从得知（这里补报）；写了但非法：`_progressionTable`
          // 已报 `invalidTable`，不再重复报——两种情况都放弃展开，绝不猜环阶。
          if (!map.containsKey('slotLevel')) {
            _invalidTable(
              diagnostics,
              '$path.slots',
              'pact 原型的 slots 需要同级 slotLevel 提供环阶',
            );
          }
          return null;
        }
        normalized = _expandPactSlots(rows, slotLevels, path, diagnostics);
      } else {
        normalized = _expandCasterSlots(rows, path, diagnostics);
      }
      if (normalized == null) return null; // 压缩编码形状非法，已报 invalidTable
    }
    final slots = SlotTable.tryParse(normalized);
    if (slots == null) {
      _invalidTable(
        diagnostics,
        '$path.slots',
        'slots 必须是 20 项数组或稀疏 {"等级": 值}',
      );
    }
    return slots;
  }

  /// 是否内置档案的"每级一个计数数组"模板压缩编码（§3.1）：`[[2],[3],[4,2],…]`。
  /// 任一级不是数组就不是该编码（例如 20 项 `{环阶:数量}` 数组），原样交回。
  static bool _isCompressedSlots(Object? raw) =>
      raw is List && raw.isNotEmpty && raw.every((row) => row is List);

  /// 普通原型的展开：第 n 项的下标 + 1 即环阶（`[4,2]` → `{"1":4,"2":2}`），
  /// 0 值按编码约定省略；空行展开为**显式空表** `{}`（§3.12：该级有法术位表但
  /// 一个法术位也没有，与"未声明"不同）。
  static List<Object?>? _expandCasterSlots(
    List<Object?> rows,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    if (rows.length > 20) {
      _invalidTable(diagnostics, '$path.slots', 'slots 压缩编码最多 20 项（每级一项）');
      return null;
    }
    final expanded = <Object?>[];
    for (var index = 0; index < rows.length; index++) {
      final level = index + 1;
      final row = rows[index] as List;
      if (row.length > 9) {
        _invalidTable(
          diagnostics,
          '$path.slots',
          '$level 级的法术位最多 9 项（环阶 1..9）',
        );
        return null;
      }
      final slots = <String, Object?>{};
      for (var ring = 0; ring < row.length; ring++) {
        final count = _slotCount(row[ring]);
        if (count == null) {
          _invalidTable(
            diagnostics,
            '$path.slots',
            '$level 级第 ${ring + 1} 环的法术位必须是非负整数',
          );
          return null;
        }
        if (count == 0) continue;
        slots['${ring + 1}'] = count;
      }
      expanded.add(slots);
    }
    return expanded;
  }

  /// `pact` 原型的展开：每级只有一个计数，环阶由同级 `slotLevel[L]` 提供
  /// （5 级 → `{"3": 2}`，与旧 `pactSlotMaximums` 的形状一致，§3.3）。
  static List<Object?>? _expandPactSlots(
    List<Object?> rows,
    IntTable slotLevels,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    if (rows.length > 20) {
      _invalidTable(diagnostics, '$path.slots', 'slots 压缩编码最多 20 项（每级一项）');
      return null;
    }
    final expanded = <Object?>[];
    for (var index = 0; index < rows.length; index++) {
      final level = index + 1;
      final row = rows[index] as List;
      if (row.length != 1) {
        _invalidTable(diagnostics, '$path.slots', 'pact 原型的每级 slots 只能有一个环阶计数');
        return null;
      }
      final count = _slotCount(row.single);
      if (count == null) {
        _invalidTable(diagnostics, '$path.slots', '$level 级的法术位数量必须是非负整数');
        return null;
      }
      final slotLevel = slotLevels.at(level);
      if (slotLevel == null || slotLevel < 1 || slotLevel > 9) {
        _invalidTable(
          diagnostics,
          '$path.slots',
          'pact 原型 $level 级缺少可用的 slotLevel（1..9）',
        );
        return null;
      }
      expanded.add(<String, Object?>{'$slotLevel': count});
    }
    return expanded;
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

  /// 档案可选的 `classAliases`：展示名/别名（小写）→ 规范 slug，填充
  /// [RuleProfile.aliases]。
  ///
  /// 契约 §3.6 的档案补齐只按 slug 查找；别名表的用途是**过渡期**解析只有散文
  /// `classSummary` 的老角色（`Dnd5eRules` 的旧签名 shim），因此它只承载"展示名
  /// → 规范 slug"这一件事，不含任何规则数值。
  ///
  /// 别名指向不存在的 slug 属于档案数据错误：报 error 并整包阻断（与
  /// `unknownArchetype` 同类），绝不留给运行期静默失效。别名键与职业 slug 同名时
  /// `classes` 优先（[RuleProfile.classRules] 先查 slug），因此不额外报错。
  static Map<String, String> _parseClassAliases(
    Map<String, Object?> raw,
    Map<String, ClassRuleSet> classes,
    List<RuleDiagnostic> diagnostics,
  ) {
    final aliases = <String, String>{};
    final rawAliases = raw['classAliases'];
    if (rawAliases == null) return aliases;
    if (rawAliases is! Map) {
      _invalidTable(
        diagnostics,
        r'$.classAliases',
        'classAliases 必须是 {"别名": "slug"} 对象',
      );
      return aliases;
    }
    rawAliases.forEach((key, value) {
      final path = '${r'$.classAliases'}.$key';
      final alias = '$key'.trim().toLowerCase();
      final slug = value is String ? value.trim().toLowerCase() : '';
      if (alias.isEmpty || slug.isEmpty) {
        _invalidTable(diagnostics, path, '别名与 slug 都必须是非空字符串');
        return;
      }
      if (!classes.containsKey(slug)) {
        _invalidTable(diagnostics, path, '别名指向不存在的职业 slug "$slug"');
        return;
      }
      aliases[alias] = slug;
    });
    return aliases;
  }

  /// 原型存在性校验（§3.3）：引用不存在的原型必须报 error，而不是静默无法术位。
  static void _validateArchetypes(
    Map<String, ClassRuleSet> classes,
    Map<String, ClassProgression> progressions,
    List<RuleDiagnostic> diagnostics,
  ) {
    for (final entry in classes.entries) {
      _validateArchetype(
        archetype: entry.value.spellcasting?.archetype,
        path: '\$.classes.${entry.key}.spellcasting.archetype',
        progressions: progressions,
        diagnostics: diagnostics,
      );
    }
  }

  /// 单个 `archetype` 的存在性（§3.3、§5.1）。**唯一实现**：内置档案解析
  /// （[_validateArchetypes]）与条目 `structured.classRules` 的导入期校验
  /// （[validateEntryClassRules]）都走这里，档案查询逻辑不复制第二份。
  static void _validateArchetype({
    required String? archetype,
    required String path,
    required Map<String, ClassProgression> progressions,
    required List<RuleDiagnostic> diagnostics,
  }) {
    if (archetype == null || progressions.containsKey(archetype)) return;
    diagnostics.add(
      RuleDiagnostic(
        path: path,
        severity: RuleSeverity.error,
        code: 'unknownArchetype',
        message: '未知原型 "$archetype"',
      ),
    );
  }

  /// 条目 `structured.classRules` 的**档案侧**校验（§4.2/§4.3、§5.1、§5.2）。
  ///
  /// 导入期唯一入口：形状/类型问题由 [ClassRuleSet.parse]（`abilities` 传档案的）
  /// 负责，这里只补"必须查档案才能判断"的部分，不复制任何档案查询：
  /// - `spellcasting.archetype` 必须存在于档案 `progressions` → error `unknownArchetype`；
  /// - 施法职业（`mode != none`）没有任何法术位来源（自身 `slots` 与所挂原型都没有）
  ///   → warning `missingCoreField`：运行期 [ResolvedClassRules.spellSlots] 会恒为空；
  /// - 施法职业未声明 `prepared` → warning `missingPreparedColumn`
  ///   （原型不承载该列，编辑器因此不限制准备数量）；
  /// - 资源的 `maximum.table` 在 [ClassResourceRule.startsAtLevel] 及以上出现 0
  ///   → warning `zeroLevelResource`（显式 0 = "存在但上限为 0"，多半是作者想表达
  ///   "该等级还没有这个资源"，那应该用 `startsAtLevel`）。
  ///
  /// 只对**条目声明**调用：内置档案自己的表由资产测试兜底，导入期的 warning
  /// 是针对第三方包的作者提示（§5.2 的 warning 语义就是"可导入，导入预览中列出"）。
  static void validateEntryClassRules({
    required RuleProfile profile,
    required ClassRuleSet? entryRules,
    required String path,
    required List<RuleDiagnostic> diagnostics,
  }) {
    if (entryRules == null) return;
    final spellcasting = entryRules.spellcasting;
    _validateArchetype(
      archetype: spellcasting?.archetype,
      path: '$path.spellcasting.archetype',
      progressions: profile.progressions,
      diagnostics: diagnostics,
    );
    if (spellcasting != null && spellcasting.mode != 'none') {
      if (spellcasting.prepared == null) {
        _addWarning(
          diagnostics,
          '$path.spellcasting.prepared',
          'missingPreparedColumn',
          '施法职业未声明 prepared：原型不提供该列，编辑器将不限制准备数量',
        );
      }
      final ownsSlots = spellcasting.slots != null;
      final archetypeSlots =
          profile.progression(spellcasting.archetype)?.slots != null;
      if (!ownsSlots && !archetypeSlots) {
        _addWarning(
          diagnostics,
          '$path.spellcasting',
          'missingCoreField',
          '施法职业既未声明 spellcasting.slots 也未挂载提供法术位的原型：'
              '角色卡的法术位将缺省',
        );
      }
    }
    for (var index = 0; index < entryRules.resources.length; index++) {
      _validateResourceZeroLevels(
        entryRules.resources[index],
        '$path.resources[$index]',
        diagnostics,
      );
    }
  }

  /// 资源上限表在 `startsAtLevel` 及以上为 0 的档位（§5.2 `zeroLevelResource`）。
  ///
  /// 只看**表**形态：常量 `maximum: 0` 没有等级概念，不触发。取值语义走
  /// [IntTable.at]（高于最后声明等级沿用最后声明值），因此 `{"1": 0}` 这种
  /// "从头就写 0" 的表会被如实报出来，而不是靠调用方各自判空。
  static void _validateResourceZeroLevels(
    ClassResourceRule resource,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    final table = resource.maximum.table;
    if (table == null) return;
    final zeroLevels = <int>[
      for (var level = table.minLevel; level <= table.maxLevel; level++)
        if (level >= resource.startsAtLevel && table.at(level) == 0) level,
    ];
    if (zeroLevels.isEmpty) return;
    _addWarning(
      diagnostics,
      '$path.maximum.table',
      'zeroLevelResource',
      '资源表在 ${zeroLevels.join('、')} 级为 0：该级上限为 0（显式 0 表示'
          '"存在但上限为 0"；若想表达"该等级还没有这个资源"，请改用 startsAtLevel）',
    );
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
      // 声明范围的唯一口径在 ResolvedClassRules 里：条目各表 ∪ 档案各表（§3.12）。
      // 此处只提供两侧的 ClassRuleSet，不再各自算一份 min/max。
      entryRules: entryRules,
      archiveRules: fromArchive,
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

/// 可导入的提示级诊断（§5.2）：只提示，不阻断。
void _addWarning(
  List<RuleDiagnostic> out,
  String path,
  String code,
  String message,
) => out.add(
  RuleDiagnostic(
    path: path,
    severity: RuleSeverity.warning,
    code: code,
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

/// 压缩编码里的法术位计数：必须是非负整数（小数、负数、非数字一律非法）。
int? _slotCount(Object? raw) => raw is int && raw >= 0 ? raw : null;
