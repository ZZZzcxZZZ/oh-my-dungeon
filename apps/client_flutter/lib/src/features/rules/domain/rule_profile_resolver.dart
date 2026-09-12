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
import 'rule_field_path.dart';
import 'rule_override_declaration.dart';
import 'rule_override_priority.dart';
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
    _validateArchiveResources(classes, diagnostics);

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

  /// 档案资源必须自带 `name` 与 `maximum`（§3.1、§3.4）：内置档案不是补丁，
  /// 没有"低 tier 可补齐"这回事，缺一列就整包失败（fail-fast）。报错码沿用
  /// `invalidMaxSpec`，path 精确到列。
  static void _validateArchiveResources(
    Map<String, ClassRuleSet> classes,
    List<RuleDiagnostic> diagnostics,
  ) {
    classes.forEach((slug, rules) {
      for (var index = 0; index < rules.resources.length; index++) {
        final resource = rules.resources[index];
        final path = '\$.classes.$slug.resources[$index]';
        if (resource.name == null) {
          _invalidTable(diagnostics, '$path.name', '档案资源必须声明 name');
        }
        if (resource.maximum == null) {
          _invalidTable(diagnostics, '$path.maximum', '档案资源必须声明 maximum');
        }
      }
    });
  }

  /// 条目 `structured.classRules` 的**档案侧**校验（§4.2/§4.3、§5.1、§5.2）。
  ///
  /// 导入期唯一入口：形状/类型问题由 [ClassRuleSet.parse]（`abilities` 传档案的）
  /// 负责，这里只补"必须查档案才能判断"的部分，不复制任何档案查询：
  /// - `spellcasting.archetype` 必须存在于档案 `progressions` → error `unknownArchetype`；
  /// - 施法职业（`mode != none`）没有任何法术位来源（自身 `slots` 与所挂原型都没有）
  ///   → warning `missingCoreField`：运行期 [ResolvedClassRules.spellSlots] 会恒为空；
  /// - 施法职业**整块缺** `spellcasting`（[hasSpellChoiceIntent] 为真，即条目 `rules`
  ///   里有 `optionType == 'spell'` 的选择）→ warning `missingCoreField`：`mode` 无从
  ///   得知，第一条判断不会触发，但运行期连施法属性都拿不到；
  /// - **写了** `spellcasting` 块却**没写 `mode`** 且档案也没有同 slug 施法可继承
  ///   （parse 把缺省值落成 `none`）→ warning `missingCoreField`：块里已声明的其它列
  ///   （`prepared` / `slots` / `ability`…）会被 `mode: none` 全部短路，运行期一个都
  ///   不生效。这是"静默丢弃"的入口，必须报出来，让作者显式写 `mode`；
  /// - 施法职业未声明 `prepared` → warning `missingPreparedColumn`
  ///   （原型不承载该列，编辑器因此不限制准备数量）；
  /// - 资源的 `maximum.table` 在 [ClassResourceRule.startsAtLevel] 及以上出现 0
  ///   → warning `zeroLevelResource`（显式 0 = "存在但上限为 0"，多半是作者想表达
  ///   "该等级还没有这个资源"，那应该用 `startsAtLevel`）。
  ///
  /// 只对**条目声明**调用：内置档案自己的表由资产测试兜底，导入期的 warning
  /// 是针对第三方包的作者提示（§5.2 的 warning 语义就是"可导入，导入预览中列出"）。
  ///
  /// [archiveRules] 是**档案侧**同 slug 职业的完整规则块：条目按字段 / 列继承档案
  /// （§3.6），档案已提供 `spellcasting` 时"条目没写"不是缺省，不得误报；补丁资源
  /// 是否有低 tier 可补齐也看它。**只收这一个参数**——`archiveSpellcasting` 是同一
  /// 对象的 `spellcasting` 部分（内部派生），多一个入参就多一处"忘传 → 静默变
  /// false"的隐患。
  static void validateEntryClassRules({
    required RuleProfile profile,
    required ClassRuleSet? entryRules,
    required String path,
    required List<RuleDiagnostic> diagnostics,
    bool hasSpellChoiceIntent = false,
    ClassRuleSet? archiveRules,
  }) {
    if (entryRules == null) return;
    final spellcasting = entryRules.spellcasting;
    final archiveSpellcasting = archiveRules?.spellcasting;
    _validateArchetype(
      archetype: spellcasting?.archetype,
      path: '$path.spellcasting.archetype',
      progressions: profile.progressions,
      diagnostics: diagnostics,
    );
    // "档案已提供施法"与"条目已声明施法"在 `mode == none` 上必须同一口径：
    // §3.6 第 3 步把"缺失或 mode none"都算作无法术位/无施法属性。
    final archiveProvidesSpellcasting =
        archiveSpellcasting != null && archiveSpellcasting.mode != 'none';
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
    } else if (spellcasting == null &&
        hasSpellChoiceIntent &&
        !archiveProvidesSpellcasting) {
      // 整块缺失 + 作者意图（`optionType: "spell"` 的选择）+ 档案也没提供：
      // 运行期 `ResolvedClassRules.spellcasting` 为 null，法术位、准备上限、
      // 施法属性一起缺省。只在**两侧都没有**时报，避免把"继承内置数值"误报成缺省。
      _addWarning(
        diagnostics,
        '$path.spellcasting',
        'missingCoreField',
        '该职业声明了法术选择（optionType "spell"）却完全未声明 spellcasting，'
            '档案也没有同 slug 职业可继承：角色卡的法术位与施法属性将缺省',
      );
    } else if (spellcasting != null &&
        !spellcasting.declares('mode') &&
        !archiveProvidesSpellcasting &&
        spellcasting.fields.isNotEmpty) {
      // `mode` 没写（`declares('mode')` 为 false）⇒ parse 落缺省 `none`，第一条
      // 分支不进；`spellcasting` 非 null ⇒ 第二条分支也不进。块里已声明的其它列
      // 会被 `mode: none` 静默丢弃（`fields.isNotEmpty` 此刻就等价于"含 mode 以外
      // 的列"，因为 mode 不在 fields 里）。档案也没有同 slug 施法可继承时，唯一
      // 出路是报出来。
      _addWarning(
        diagnostics,
        '$path.spellcasting',
        'missingCoreField',
        'spellcasting 未声明 mode（缺省为 none），档案也没有同 slug 施法可继承：'
            '块里已声明的列（如 prepared / slots / ability）都不会生效。'
            '想施法请写 mode: prepared / known；确实不施法请显式写 mode: none',
      );
    }
    for (var index = 0; index < entryRules.resources.length; index++) {
      _validateResourceZeroLevels(
        entryRules.resources[index],
        '$path.resources[$index]',
        diagnostics,
      );
    }
    // 补丁资源：条目资源的 id 必须在档案里有同 id 资源，或自带 name + maximum。
    // 否则运行期拿不到可展示的名称或上限（静默产出"未声明资源"），必须阻断。
    // 这是补丁语义的**唯一**合法性判据（列级合并的前置条件）。
    final archiveById = <String, ClassResourceRule>{
      for (final resource in archiveRules?.resources ?? const <ClassResourceRule>[])
        resource.id: resource,
    };
    for (var index = 0; index < entryRules.resources.length; index++) {
      final resource = entryRules.resources[index];
      final base = archiveById[resource.id];
      final name = resource.name ?? base?.name;
      final maximum = resource.maximum ?? base?.maximum;
      if (name != null && maximum != null) continue;
      diagnostics.add(
        RuleDiagnostic(
          path: '$path.resources[$index].id',
          severity: RuleSeverity.error,
          code: 'incompleteResourcePatch',
          message:
              '资源 "${resource.id}" 是补丁声明（缺 ${[
                if (name == null) 'name',
                if (maximum == null) 'maximum',
              ].join(' / ')}），但内置档案没有同 id 资源可补齐',
        ),
      );
    }
  }

  /// 资源上限表在 `startsAtLevel` 及以上为 0 的档位（§5.2 `zeroLevelResource`）。
  ///
  /// 只看**表**形态：常量 `maximum: 0` 没有等级概念，不触发。
  ///
  /// 取值语义走 [IntTable.at]（不高于当前等级的最大已声明档位；高于最后声明
  /// 等级沿用最后声明值），因此**必须显式补查 `startsAtLevel`**：
  /// `startsAtLevel: 3` + `table: {"1": 0}` 时 `minLevel..maxLevel` 只有 1 级
  /// （在 `startsAtLevel` 之前，不算），但 [IntTable.at]`(3)` 沿用 1 级的 0
  /// ——运行期 `resourcesAt` 会产出"上限 0"的资源。漏查这一档就会一条 warning
  /// 都不报，作者也看不到问题。
  static void _validateResourceZeroLevels(
    ClassResourceRule resource,
    String path,
    List<RuleDiagnostic> diagnostics,
  ) {
    final table = resource.maximum?.table;
    if (table == null) return;
    final zeroLevels = <int>[
      for (var level = table.minLevel; level <= table.maxLevel; level++)
        if (level >= resource.startsAtLevel && table.at(level) == 0) level,
    ];
    // 表范围可能整个落在 `startsAtLevel` 之前，但"沿用最后声明值"仍会让
    // `startsAtLevel` 及以上恒为 0：这一档不在上面的循环里，单独补查。
    if (table.maxLevel < resource.startsAtLevel &&
        table.at(resource.startsAtLevel) == 0) {
      zeroLevels.add(resource.startsAtLevel);
      zeroLevels.sort();
    }
    if (zeroLevels.isEmpty) return;
    _addWarning(
      diagnostics,
      '$path.maximum.table',
      'zeroLevelResource',
      '资源表在 ${zeroLevels.join('、')} 级为 0：该级上限为 0（显式 0 表示'
          '"存在但上限为 0"；若想表达"该等级还没有这个资源"，请改用 startsAtLevel）',
    );
  }

  /// 条目声明 ∪ 档案（条目优先，**顶层字段 + 列级**，§3.6、§3.7、§3.8、S3 决策 D5）。
  ///
  /// 合并顺序在代码与注释里写死：**先做 tier 之间（条目 vs 档案）的逐列 / 逐级
  /// 合并**，得到该职业自身的各列；**之后**才由 [ResolvedClassRules] 按 §3.3 决定
  /// "该列在某个等级未声明时是否回退 `archetype`"。两级关系不混在一起。
  static ResolvedClassRules resolveClassRules({
    required RuleProfile profile,
    required String slug,
    required ClassRuleSet? entryRules,
    String? entryId,
  }) {
    final fromArchive = profile.classRules(slug);
    final entryOrigin = entryId ?? '<entry>';
    final sources = <String, RuleFieldSource>{};

    final entry = entryRules == null
        ? null
        : RuleOverrideDeclaration.package(
            originId: entryOrigin,
            packageId: RuleOverrideDeclaration.packageIdOf(entryOrigin),
            entryId: entryId,
            rules: entryRules,
          );
    final archive = fromArchive == null
        ? null
        : RuleOverrideDeclaration.builtin(fromArchive);
    // 排序 + `replace` 截断的唯一实现在 RuleOverrideOrder（决策 D1/D4/D6），
    // 解析器不再自己写第二处 sort。
    final ordered = RuleOverrideOrder.effective(
      <RuleOverrideDeclaration>[?entry, ?archive],
      characterEntryId: entryId,
    );

    final spellcasting = _mergeSpellcasting(
      declarations: ordered,
      sources: sources,
    );
    return ResolvedClassRules(
      hitDie: _pickColumn<int>(
        field: RuleFieldPath.hitDie,
        declarations: ordered,
        declares: (rules) => rules.declares('hitDie'),
        read: (rules) => rules.hitDie,
        sources: sources,
      ).value,
      savingThrowAbilities:
          _pickColumn<Set<String>>(
            field: RuleFieldPath.savingThrowAbilities,
            declarations: ordered,
            declares: (rules) => rules.declares('savingThrowAbilities'),
            read: (rules) => rules.savingThrowAbilities,
            sources: sources,
          ).value ??
          const {},
      spellcasting: spellcasting,
      resources: _mergeResources(declarations: ordered, sources: sources),
      archetype: profile.progression(spellcasting?.archetype),
      fieldSources: sources,
      // 声明范围的唯一口径在 ResolvedClassRules 里：条目各表 ∪ 档案各表（§3.12）。
      // 此处只提供两侧的 ClassRuleSet，不再各自算一份 min/max。
      entryRules: entryRules,
      archiveRules: fromArchive,
    );
  }
}

/// 列级取值的**唯一**实现（标量列：`hitDie` / `savingThrowAbilities` /
/// `spellcasting.mode|ability|listTags|archetype` / `resources` 的合键等）。
///
/// [declarations] 必须已按优先级**从高到低**排好（排序的唯一实现在
/// `RuleOverrideOrder.effective`，本文件不排序）。取"第一个声明过该列"的声明的值
/// 即生效值；全都未声明 → `(value: null)`。
/// **显式 null 也算声明**（`archetype: null` = 清空该列），因此判据只看
/// `declares`，绝不看"值是否为 null"。
_ColumnPick<T> _pickColumn<T>({
  required String field,
  required List<RuleOverrideDeclaration> declarations,
  required bool Function(ClassRuleSet rules) declares,
  required T? Function(ClassRuleSet rules) read,
  required Map<String, RuleFieldSource> sources,
}) {
  for (final declaration in declarations) {
    if (!declares(declaration.rules)) continue;
    _writeSource(sources, field, declaration.originId, declaration.tier);
    return _ColumnPick(
      value: read(declaration.rules),
      originId: declaration.originId,
    );
  }
  return const _ColumnPick(value: null, originId: null);
}

/// `Table<T>` 列的取值 + 来源（决策 D5）：值走 [mergeRuleTableLevels]（逐级合并的
/// 唯一实现），来源记在"最高 tier 且声明过该列"的声明上。
///
/// 逐级的来源细节（"1..19 级来自档案、20 级来自条目"）不在本批次：§3.7 的来源粒度
/// 是列，`RuleFieldPath` 也没有等级维度。列级来源 = 该列的最高 tier 声明者。
Map<int, T> _pickTableColumn<T>({
  required String field,
  required List<RuleOverrideDeclaration> declarations,
  required bool Function(ClassRuleSet rules) declares,
  required T? Function(ClassRuleSet rules, int level) read,
  required Map<String, RuleFieldSource> sources,
}) {
  final readers = <T? Function(int level)>[];
  RuleOverrideDeclaration? owner;
  for (final declaration in declarations) {
    if (!declares(declaration.rules)) continue;
    owner ??= declaration;
    readers.add((level) => read(declaration.rules, level));
  }
  if (owner == null) return const {};
  _writeSource(sources, field, owner.originId, owner.tier);
  return mergeRuleTableLevels<T>(readers);
}

class _ColumnPick<T> {
  const _ColumnPick({required this.value, required this.originId});

  final T? value;
  final String? originId;
}

/// 来源写入的**唯一**出口（契约 §3.7）。字段路径必须来自 [RuleFieldPath]。
void _writeSource(
  Map<String, RuleFieldSource> sources,
  String field,
  String originId,
  int tier,
) {
  sources[field] = RuleFieldSource(field: field, originId: originId, tier: tier);
}

/// tier 之间（条目 vs 档案）的 `spellcasting` 列级 + 表列逐级合并（§3.6、D5）。
///
/// - 双方都没有 `spellcasting` → null（不产生来源）；
/// - 标量列逐列取"高优先级且声明过该列"的一侧（`mode` / `ability` / `listTags` /
///   `archetype`）；
/// - 表列（`slots` / `slotLevel` / `prepared` / `cantrips` / `maximumSpellLevel`）
///   在声明过该列的各 tier 之间**按等级**合并（[mergeRuleTableLevels]）；
/// - 合并结果的 `fields` 是**声明列的并集**，供下游判断"该列是否未声明"；
/// - `mode` 的默认值 `none` 在**合并之后**落，缺省不算声明（否则条目只写
///   `prepared` 时会把档案的 `mode: prepared` 误压成 `none`）。
ClassSpellcasting? _mergeSpellcasting({
  required List<RuleOverrideDeclaration> declarations,
  required Map<String, RuleFieldSource> sources,
}) {
  ClassSpellcasting? spellcastingOf(ClassRuleSet rules) => rules.spellcasting;
  bool declaresColumn(ClassRuleSet rules, String column) =>
      spellcastingOf(rules)?.declares(column) ?? false;

  final present = <ClassRuleSet>[
    for (final declaration in declarations)
      if (spellcastingOf(declaration.rules) != null) declaration.rules,
  ];
  if (present.isEmpty) return null;

  T? column<T>(String name, T? Function(ClassSpellcasting) read) =>
      _pickColumn<T>(
        field: RuleFieldPath.spellcasting(name),
        declarations: declarations,
        declares: (rules) => declaresColumn(rules, name),
        read: (rules) => read(spellcastingOf(rules)!),
        sources: sources,
      ).value;

  IntTable? intTable(String name, IntTable? Function(ClassSpellcasting) read) =>
      IntTable.fromLevels(
        _pickTableColumn<int>(
          field: RuleFieldPath.spellcasting(name),
          declarations: declarations,
          declares: (rules) => declaresColumn(rules, name),
          read: (rules, level) => read(spellcastingOf(rules)!)?.at(level),
          sources: sources,
        ),
      );

  final slots = _pickTableColumn<Map<String, int>>(
    field: RuleFieldPath.spellcasting('slots'),
    declarations: declarations,
    declares: (rules) => declaresColumn(rules, 'slots'),
    read: (rules, level) => spellcastingOf(rules)!.slots?.at(level),
    sources: sources,
  );

  return ClassSpellcasting(
    mode: column<String>('mode', (c) => c.mode) ?? 'none',
    ability: column<String>('ability', (c) => c.ability),
    listTags: column<List<String>>('listTags', (c) => c.listTags) ?? const [],
    archetype: column<String>('archetype', (c) => c.archetype),
    slots: SlotTable.fromLevels(slots),
    slotLevel: intTable('slotLevel', (c) => c.slotLevel),
    prepared: intTable('prepared', (c) => c.prepared),
    cantrips: intTable('cantrips', (c) => c.cantrips),
    maximumSpellLevel: intTable(
      'maximumSpellLevel',
      (c) => c.maximumSpellLevel,
    ),
    fields: {
      for (final declaration in declarations)
        ...?spellcastingOf(declaration.rules)?.fields,
    },
  );
}

/// tier 之间（条目 vs 档案）的 `resources` 合并（§3.4、§3.6 + 决策 D5）：
/// **按 `id` 合**，同 `id` 再按列。
///
/// - `id` 的出现顺序按"优先级从高到低"稳定排列（高 tier 新增的资源排在前面）；
/// - 每条资源的每个标量列（`name` / `recovery` / `startsAtLevel`）取"高优先级且
///   声明过该列"的一侧；
/// - `recovery` 的常量形态与 `{"table": …}` 形态是**同一条来源路径**（§3.4 的双
///   表示歧义），两者整体取同一侧，不拆开；
/// - `maximum` 是列：所有声明过该列的 tier 的 `MaxSpec` 被**分层保留**
///   （[_mergeResourceMaximum]）。最高 tier 是**表**时，该表未声明的等级逐级回退到
///   低 tier 的 `MaxSpec`（表 / 常量 / 公式都行），所以"勘误只改 20 级的上限"不必
///   重述整表；最高 tier 是整数 / 公式时它覆盖所有等级（常量 / 公式没有等级维度）；
/// - 合并后 `name` / `maximum` 仍可能为 null：导入期已用 `incompleteResourcePatch`
///   拦住条目补丁，档案侧由 `_validateArchiveResources` fail-fast。运行期
///   [ResolvedClassRules.resourcesAt] 对 null 采取"跳过"，避免产出没有上限的假资源；
/// - `description` 没有数值语义：取最高 tier 声明的非空值，**不记来源**；
/// - 合并结果的 `fields` 是**声明列的并集**，供下游判断"该列是否未声明"。
List<ClassResourceRule> _mergeResources({
  required List<RuleOverrideDeclaration> declarations,
  required Map<String, RuleFieldSource> sources,
}) {
  final ids = <String>[];
  for (final declaration in declarations) {
    for (final resource in declaration.rules.resources) {
      if (!ids.contains(resource.id)) ids.add(resource.id);
    }
  }

  final merged = <ClassResourceRule>[];
  for (final id in ids) {
    bool declares(ClassRuleSet rules, String column) =>
        _resourceOf(rules, id)?.declares(column) ?? false;

    T? column<T>(String name, T? Function(ClassResourceRule) read) =>
        _pickColumn<T>(
          field: RuleFieldPath.resource(id, name),
          declarations: declarations,
          declares: (rules) => declares(rules, name),
          read: (rules) => read(_resourceOf(rules, id)!),
          sources: sources,
        ).value;

    // 常量形态与表形态是**同一条来源路径**（§3.4 的双表示歧义）：两者必须
    // 整体取同一侧，不能"常量取条目、表取档案"。
    final recovery = _pickColumn<({String? constant, StringTable? table})>(
      field: RuleFieldPath.resource(id, 'recovery'),
      declarations: declarations,
      declares: (rules) => declares(rules, 'recovery'),
      read: (rules) {
        final rule = _resourceOf(rules, id)!;
        return (constant: rule.recovery, table: rule.recoveryTable);
      },
      sources: sources,
    ).value;

    // `description` 没有数值语义：取最高 tier 声明的非空值，**不记来源**。
    String? description;
    for (final declaration in declarations) {
      final value = _resourceOf(declaration.rules, id)?.description;
      if (value != null) {
        description = value;
        break;
      }
    }

    merged.add(
      ClassResourceRule(
        id: id,
        name: column<String>('name', (r) => r.name),
        maximum: _mergeResourceMaximum(
          id: id,
          declarations: declarations,
          sources: sources,
        ),
        recovery: recovery?.constant,
        recoveryTable: recovery?.table,
        startsAtLevel:
            column<int>('startsAtLevel', (r) => r.startsAtLevel) ?? 1,
        description: description,
        fields: <String>{
          for (final declaration in declarations)
            ...?_resourceOf(declaration.rules, id)?.fields,
        },
      ),
    );
  }
  return merged;
}

/// 按 `id` 找资源；没有同 id 时返回 null（`id` 是合键，S3 起跨 tier 对齐）。
ClassResourceRule? _resourceOf(ClassRuleSet rules, String id) {
  for (final resource in rules.resources) {
    if (resource.id == id) return resource;
  }
  return null;
}

/// `resources.<id>.maximum` 的列级 + 逐级合并（决策 D5）。
///
/// **分层保留所有 tier 的 `MaxSpec`**（`withFallback` 串成高 → 低），而不是只留
/// 最高 tier 那一份：
/// - 最高 tier 是**表**时，本表未声明的等级继续问低 tier 的 `MaxSpec`——常量 / 公式
///   原样保留，运行期 [MaxSpec.resolve] 再算（`formula: "level"` 因此仍按角色等级
///   结算），不会被静默丢弃；
/// - 最高 tier 是整数 / 公式时它覆盖所有等级（没有等级维度），后备层自然不会被问到；
/// - 表 + 表的逐级结果与旧的 `mergeRuleTableLevels` 逐项相等（`Table.at` 自己负责
///   "高于最后声明沿用最后声明值"），因此这不是行为变化，而是补上混合形态的洞；
/// - `minimum` 取最高 tier 声明者的（[MaxSpec.resolve] 里作为最终下限）；
/// - 来源仍只有一条：最高 tier 的声明者（§3.7 的来源粒度是列，见 `RuleFieldPath`
///   的"路径无等级维度"已知限制）。
MaxSpec? _mergeResourceMaximum({
  required String id,
  required List<RuleOverrideDeclaration> declarations,
  required Map<String, RuleFieldSource> sources,
}) {
  final field = RuleFieldPath.resource(id, 'maximum');
  final contributors = <RuleOverrideDeclaration>[];
  for (final declaration in declarations) {
    final rule = _resourceOf(declaration.rules, id);
    if (rule == null || !rule.declares('maximum')) continue;
    contributors.add(declaration);
  }
  if (contributors.isEmpty) return null;
  final owner = contributors.first;
  _writeSource(sources, field, owner.originId, owner.tier);

  // 从最低 tier 往最高 tier 组装后备链：`spec.withFallback(已组装的低层链)`。
  MaxSpec? layered;
  for (final declaration in contributors.reversed) {
    final spec = _resourceOf(declaration.rules, id)!.maximum;
    if (spec == null) continue;
    layered = layered == null ? spec : spec.withFallback(layered);
  }
  return layered;
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
