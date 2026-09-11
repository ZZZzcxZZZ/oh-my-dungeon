// 内置档案解析 + "条目声明 ∪ 档案"的字段级合并（§3.6、§3.7、§3.8）。
//
// 只有两级优先级：内置档案（tier 0）< 角色所用条目的声明（tier 100）。
// 不做全局条目扫描、没有 priority 字段（§3.8）；未声明即不猜（§3.6 第 3 步）。
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
  /// 解析内置档案（§3.1）。`abilities` / `skills` 以档案为唯一权威参照表。
  static RuleProfileResolution resolveBuiltin(Map<String, Object?> raw) {
    final diagnostics = <RuleDiagnostic>[];
    final abilities = _stringSet(raw['abilities']);
    final skills = <String, String>{};
    final rawSkills = raw['skills'];
    if (rawSkills is List) {
      for (final item in rawSkills) {
        if (item is Map) skills['${item['name']}'] = '${item['ability']}';
      }
    }

    final progressions = <String, ClassProgression>{};
    final rawProgressions = raw['progressions'];
    if (rawProgressions is Map) {
      rawProgressions.forEach((key, value) {
        if (value is! Map) return;
        final map = Map<String, Object?>.from(value);
        final name = '$key';
        final slots = SlotTable.tryParse(map['slots']);
        // 空数组 / 空对象是"该原型没有声明任何档位"的合法写法（§3.1 的 `none`
        // 就是 `{"slots": []}`），不是错误；只有写了内容却解析不出表才报错。
        if (map['slots'] != null &&
            !_isEmptyTable(map['slots']) &&
            slots == null) {
          diagnostics.add(
            RuleDiagnostic(
              path: '\$.progressions.$name.slots',
              severity: RuleSeverity.error,
              code: 'invalidTable',
              message: 'slots 必须是 20 项数组或稀疏 {"等级": 值}',
            ),
          );
        }
        progressions[name] = ClassProgression(
          name: name,
          minimumLevel: map['minimumLevel'] is num
              ? (map['minimumLevel']! as num).toInt()
              : 1,
          slots: slots,
          slotLevel: IntTable.tryParse(map['slotLevel']),
          prepared: IntTable.tryParse(map['prepared']),
          cantrips: IntTable.tryParse(map['cantrips']),
          maximumSpellLevel: IntTable.tryParse(map['maximumSpellLevel']),
        );
      });
    }

    final classes = <String, ClassRuleSet>{};
    final aliases = <String, String>{};
    final rawClasses = raw['classes'];
    if (rawClasses is Map) {
      rawClasses.forEach((key, value) {
        if (value is! Map) return;
        final slug = '$key'.trim().toLowerCase();
        classes[slug] = ClassRuleSet.parse(
          Map<String, Object?>.from(value),
          path: r'$.classes.' + slug,
          diagnostics: diagnostics,
          abilities: abilities.isEmpty ? kDefaultAbilities : abilities,
        );
      });
    }

    // 原型存在性校验（§3.3）：引用不存在的原型必须报 error，而不是静默无法术位。
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

    final failed = diagnostics.any((d) => d.severity == RuleSeverity.error);
    return RuleProfileResolution(
      profile: failed
          ? null
          : RuleProfile(
              abilities: abilities.isEmpty ? kDefaultAbilities : abilities,
              skills: skills.isEmpty
                  ? {for (final name in kDefaultSkills) name: ''}
                  : skills,
              progressions: progressions,
              classes: classes,
              aliases: aliases,
            ),
      diagnostics: diagnostics,
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

    // 逐字段独立判断：只有该侧**显式声明过**这个字段才取它的值，未声明就回退；
    // 两侧都没声明则保持"未声明"（null / 空集合），绝不按名字相近回退（§3.6）。
    T? pick<T>(String field, T? Function(ClassRuleSet) read) {
      final fromEntry = entryRules != null && entryRules.declares(field)
          ? read(entryRules)
          : null;
      if (fromEntry != null) {
        sources[field] = RuleFieldSource(
          field: field,
          originId: entryOrigin,
          tier: kEntryTier,
        );
        return fromEntry;
      }
      // 档案没声明过的字段不记来源：ClassRuleSet 的集合字段默认是空集合/空表，
      // 不能把"默认值"当成"档案补齐"，否则来源记录会凭空多出字段（§3.7）。
      final fromBuiltin = fromArchive != null && fromArchive.declares(field)
          ? read(fromArchive)
          : null;
      if (fromBuiltin != null) {
        sources[field] = RuleFieldSource(
          field: field,
          originId: kBuiltinOriginId,
          tier: kBuiltinTier,
        );
        return fromBuiltin;
      }
      return null;
    }

    final spellcasting = pick<ClassSpellcasting>(
      'spellcasting',
      (rules) => rules.spellcasting,
    );
    return ResolvedClassRules(
      hitDie: pick<int>('hitDie', (rules) => rules.hitDie),
      savingThrowAbilities:
          pick<Set<String>>(
            'savingThrowAbilities',
            (rules) => rules.savingThrowAbilities,
          ) ??
          const {},
      spellcasting: spellcasting,
      resources:
          pick<List<ClassResourceRule>>(
            'resources',
            (rules) => rules.resources,
          ) ??
          const [],
      archetype: profile.progression(spellcasting?.archetype),
      fieldSources: sources,
      declaredMaxLevel: entryRules?.declaredMaxLevel,
      declaredMinLevel: entryRules?.declaredMinLevel,
    );
  }

  static Set<String> _stringSet(Object? raw) {
    if (raw is! Iterable) return const {};
    return raw.map((item) => '$item'.trim().toLowerCase()).toSet();
  }
}

/// 空数组 / 空对象 = 没有声明任何档位（§3.1 的 `none` 原型就是 `[]`），不是错误。
bool _isEmptyTable(Object? raw) =>
    (raw is List && raw.isEmpty) || (raw is Map && raw.isEmpty);
