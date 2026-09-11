// `RuleProfile` 与"条目声明 ∪ 内置档案"的解析结果（§3.1、§3.7、§3.8、§3.12）。
//
// 字段级合并的读取语义集中在这里：
// - `spellSlots`：条目**已声明**的等级整级替换（显式空表 `{}` 也算已声明），
//   只有 `at` 返回 null（未声明）才回退原型（§3.3、§3.12）。
// - `preparedLimit` / `cantripLimit`：**只看职业自身**。原型不承载这两列（§3.1），
//   因此没有原型回退路径。
// - `maxSpellLevel`：自身表 → 原型表 → null。
import 'class_rule_set.dart';
import 'rule_values.dart';

/// 内置档案的来源 id（tier 0）。条目声明的来源是条目 id（tier 100，§3.7、§3.8）。
const kBuiltinOriginId = 'builtin:dnd5e-2024';

/// 内置档案的优先级 tier（§3.8）。条目声明为 100。
const kBuiltinTier = 0;
const kEntryTier = 100;

/// 契约法术位的原型名（§3.1、§3.3）。
///
/// 它是"是否使用契约魔法"的**唯一**判据：只看 `spellcasting.archetype` 挂载到的
/// 原型名，**不看 `mode`**（2024 邪术师写 `mode: "prepared"` + `archetype: "pact"`，
/// 它准备法术，但法术位走契约魔法）。读取口只有 [ResolvedClassRules.usesPactMagic]。
const kPactArchetype = 'pact';

/// 某个字段最终取自哪里（§3.7）。
class RuleFieldSource {
  const RuleFieldSource({
    required this.field,
    required this.originId,
    required this.tier,
  });

  final String field;
  final String originId; // 'builtin:dnd5e-2024' 或条目 id
  final int tier; // 0 内置档案 / 100 条目声明

  @override
  String toString() => 'RuleFieldSource($field ← $originId, tier $tier)';
}

/// `progressions.<name>`：跨职业共享的进阶模板（§3.1）。
///
/// 契约规定原型**只承载** `slots` / `slotLevel`（仅 pact）/ `maximumSpellLevel`
/// （外加 `minimumLevel` 这一元数据）。`prepared` / `cantrips` 逐职业不同，必须有
/// 职业自己的 `spellcasting` 承载——因此这两个字段**不在类型上存在**，让"禁止原型
/// 承载它们"由编译期保证，而不是只靠注释（解析期另有 `unknownField` 白名单，§3.1）。
class ClassProgression {
  const ClassProgression({
    required this.name,
    this.minimumLevel = 1,
    this.slots,
    this.slotLevel,
    this.maximumSpellLevel,
  });

  final String name;
  final int minimumLevel;
  final SlotTable? slots;
  final IntTable? slotLevel;
  final IntTable? maximumSpellLevel;
}

/// 不可变的内置档案：只含数值与枚举（§3.1）。
class RuleProfile {
  const RuleProfile({
    required this.abilities,
    required this.skills,
    required this.progressions,
    required this.classes,
    this.aliases = const {},
  });

  final Set<String> abilities;

  /// 技能名 → 属性键（作为校验参照表，§3.1）。
  final Map<String, String> skills;

  final Map<String, ClassProgression> progressions;

  /// slug（小写）→ 规则。
  final Map<String, ClassRuleSet> classes;

  /// 别名（小写）→ slug。
  final Map<String, String> aliases;

  /// 大小写归一（`trim().toLowerCase()`）+ 别名回退；未命中返回 null（§3.6）。
  /// **绝不**按名字相近匹配。
  ClassRuleSet? classRules(String key) {
    final normalized = key.trim().toLowerCase();
    return classes[normalized] ?? classes[aliases[normalized]];
  }

  ClassProgression? progression(String? name) =>
      name == null ? null : progressions[name];
}

/// 某个等级真实存在的职业资源（上限已结算，§3.12）。
class ResolvedResource {
  const ResolvedResource({
    required this.id,
    required this.name,
    required this.maximum,
    required this.recovery,
  });

  final String id;
  final String name;
  final int maximum;
  final String recovery;
}

/// 条目声明 ∪ 内置档案（条目优先，字段级）之后的职业规则（§3.6、§3.7）。
class ResolvedClassRules {
  const ResolvedClassRules({
    this.hitDie,
    this.savingThrowAbilities = const {},
    this.spellcasting,
    this.resources = const [],
    this.fieldSources = const {},
    this.archetype,
    this.entryRules,
    this.archiveRules,
  });

  final int? hitDie;
  final Set<String> savingThrowAbilities;
  final ClassSpellcasting? spellcasting;
  final List<ClassResourceRule> resources;
  final ClassProgression? archetype;
  final Map<String, RuleFieldSource> fieldSources;

  /// 条目自身声明的规则块（`structured.classRules`；未声明为 null）。
  final ClassRuleSet? entryRules;

  /// 内置档案同 slug 职业的规则块（未命中为 null）。
  final ClassRuleSet? archiveRules;

  /// 声明范围的**唯一**口径（§3.12）：条目各表范围 ∪ 内置档案同 slug 职业的
  /// 相应范围。条目 `progression[].levels` 由 [DeclaredLevels] 并上——只有它
  /// 拿得到条目上下文。`max` 为 null 表示合并后仍无任何等级声明。
  ///
  /// 档案侧**必须**并进来（哪怕条目自己声明了同名数值字段）：界面在"条目声明
  /// 覆盖档案"时仍应看到档案补出的等级区间，否则同一角色在不同界面数字不同。
  int? get declaredMaxLevel => _declaredBound(
    <int?>[entryRules?.declaredMaxLevel, archiveRules?.declaredMaxLevel],
    (a, b) => a > b ? a : b,
  );

  /// 声明范围口径的 min（各来源最早声明等级；全部未声明为 null）。
  int? get declaredMinLevel => _declaredBound(
    <int?>[entryRules?.declaredMinLevel, archiveRules?.declaredMinLevel],
    (a, b) => a < b ? a : b,
  );

  static int? _declaredBound(
    List<int?> levels,
    int Function(int a, int b) pick,
  ) {
    final declared = levels.whereType<int>();
    return declared.isEmpty ? null : declared.reduce(pick);
  }

  /// `mode == 'none'` 即"不使用施法"：无施法属性（§3.6 第 3 步）。
  String? get spellcastingAbility =>
      spellcastingMode == 'none' ? null : spellcasting?.ability;

  String get spellcastingMode => spellcasting?.mode ?? 'none';

  /// 是否使用契约魔法：**唯一判据**是所挂载的原型名是 [kPactArchetype]。
  /// `mode` 不参与判断——`mode: "pact"` 已不是合法取值（§3.3），2024 邪术师写成
  /// `mode: "prepared"` + `archetype: "pact"`。shim 与所有调用方都走这里，
  /// 不再有第二处"mode 或 archetype"的双重信号。
  bool get usesPactMagic => archetype?.name == kPactArchetype;

  /// 法术位：自身 slots 表优先（**已声明**的等级整级替换，哪怕是空表 `{}`）；
  /// 自身未声明该等级（`at` 返回 null）才回退原型；原型也低于 `minimumLevel`
  /// 或 mode 为 none 时为空表（§3.3、§3.12）。
  Map<String, int> spellSlots(int level) {
    if (spellcastingMode == 'none') return const {};
    final own = spellcasting?.slots?.at(level);
    if (own != null) return own;
    final progression = archetype;
    if (progression == null || level < progression.minimumLevel) {
      return const {};
    }
    return progression.slots?.at(level) ?? const {};
  }

  /// 契约魔法法术位的环阶：与 [maxSpellLevel] 走同一套两级取值（§3.3、§3.12）——
  /// `mode == 'none'`、低于原型 `minimumLevel`、两侧都未声明时都是 null。
  int? pactSlotLevel(int level) =>
      _pick(level, (c) => c.slotLevel, (p) => p.slotLevel);

  /// 已准备/已知法术上限：**只看职业自身**，原型不提供这一列（§3.1、§3.3）。
  /// 未声明返回 null，不回退原型、不猜。
  int? preparedLimit(int level) {
    if (spellcastingMode == 'none') return null;
    return spellcasting?.prepared?.at(level);
  }

  /// 戏法数量上限：与 [preparedLimit] 同规则，职业独有（§3.1、§3.3）。
  int? cantripLimit(int level) {
    if (spellcastingMode == 'none') return null;
    return spellcasting?.cantrips?.at(level);
  }

  /// 最高可学/可准备环阶：自身表 → 原型表 → null（§3.3）。
  int? maxSpellLevel(int level) =>
      _pick(level, (c) => c.maximumSpellLevel, (p) => p.maximumSpellLevel);

  /// `Table` 的两级取值：自身已声明该等级 → 用它；否则回退原型。
  int? _pick(
    int level,
    IntTable? Function(ClassSpellcasting) own,
    IntTable? Function(ClassProgression) fromArchetype,
  ) {
    if (spellcastingMode == 'none') return null;
    final rules = spellcasting;
    if (rules != null) {
      final value = own(rules)?.at(level);
      if (value != null) return value; // 已声明该等级（含"高于最后声明沿用"）
    }
    final progression = archetype;
    if (progression == null || level < progression.minimumLevel) return null;
    return fromArchetype(progression)?.at(level);
  }

  /// 该等级真实存在的资源。`startsAtLevel` 之前的等级整条跳过；
  /// 上限表在该等级**未声明**（[MaxSpec.resolve] 返回 null）的资源也跳过，
  /// 绝不产出"上限 0"的假资源（§3.12）。表里显式写 0 才是"存在但上限 0"。
  List<ResolvedResource> resourcesAt(int level, Map<String, int> abilities) {
    final result = <ResolvedResource>[];
    for (final rule in resources) {
      if (level < rule.startsAtLevel) continue;
      final maximum = rule.maximum.resolve(level: level, abilities: abilities);
      if (maximum == null) continue;
      result.add(
        ResolvedResource(
          id: rule.id,
          name: rule.name,
          maximum: maximum,
          recovery: rule.recoveryAt(level),
        ),
      );
    }
    return result;
  }
}
