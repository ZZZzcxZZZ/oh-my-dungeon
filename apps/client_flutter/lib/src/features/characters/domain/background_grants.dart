import '../../content/domain/content_entry.dart';
import '../../rules/domain/character_build.dart';
import '../../rules/domain/character_rule_definition.dart';
import '../../rules/domain/character_rules_engine.dart';

/// 背景条目声明的**技能熟练**（决策 D10 的**唯一读取口径**）。
///
/// 背景技能由条目自己的 `rules.progression[].grants`（或 `rules.grants`）承担：
/// `kind: "proficiency"` + `target: "skill:<档案规范名>"`。这里刻意**复用**
/// [CharacterRulesEngine]（授予解析的唯一实现），而不是另写一遍 grants 遍历——
/// 否则"背景授予怎么算"会有第二份解释（`requires`、内联选项、逐级步骤都会分叉）。
///
/// 语义（与 §3.6 一致）：
/// - 条目**没声明**技能熟练 → 返回空集合（"未声明即不猜"）。旧实现按背景中文名
///   硬编码一张预设表、并给未知背景发一套士兵技能（`运动` / `威吓`），那是猜测；
/// - 只认 `skill:<名>` 形式的授予；`save:` 等其它熟练不属于背景技能；
/// - 名字必须在档案的规范技能清单内（引擎与导入期同源），未知名字不会出现。
Set<String> backgroundSkillProficiencies({
  required Iterable<ContentEntry> entries,
  required String? backgroundEntryId,
}) {
  if (backgroundEntryId == null || backgroundEntryId.trim().isEmpty) {
    return const <String>{};
  }
  final engine = CharacterRulesEngine(
    entries: <String, ContentEntry>{
      for (final entry in entries) entry.id: entry,
    },
  );
  final ledger = engine.evaluate(
    CharacterBuild(
      level: 1,
      selections: <String, String>{'background': backgroundEntryId},
    ),
    // 背景技能是固定授予，与选择额度无关；`poolLimits` 必填只是防"漏传静默不限"。
    poolLimits: const <String, int>{},
  );
  return <String>{
    for (final grant in ledger.grantsOfKind(RuleGrantKind.proficiency))
      if ((grant.target ?? '').startsWith('skill:'))
        grant.target!.substring('skill:'.length),
  };
}
