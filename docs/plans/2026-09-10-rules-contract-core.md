# 规则契约核心（P0–P2）实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 把 D&D 2024 规则数值从 Dart 代码搬进随包发布的内置规则档案，删除全部中文职业名子串匹配，并让"完全自制的职业条目"只靠 `structured.classRules` 就能产出正确的 HP / 豁免 / 技能选择 / 法术位 / 职业资源 / 准备法术上限。

**架构：** 新增只含数值的内置档案 `assets/rules/dnd5e-2024.rules.json`（tier 0）。`Dnd5eRules` 退化为"纯运算 + 读档案"的查询层，启动时一次性 `configure` 一个不可变 `RuleProfile`。第三方/私有包的职业声明写在条目 `structured.classRules`（tier 100），在用到该条目时与档案做**字段级合并**（条目优先）——不做全局条目扫描，不引入优先级字段。规则字段的解析与校验集中在一个纯函数式解析器 `RuleProfileResolver`，导入器把它的诊断翻译成整包阻断 error 或导入 warning。

**技术栈：** Flutter 3.41 / Dart 3.11、`flutter_test`、Drift（本次不改 schema）、Python 3（私有提取脚本 `scripts/extract_phb_2024_v2.py`）、`npm run check` 门禁。

**规格：** `docs/specs/2026-09-10-rules-contract-design.md`（§3.1–§3.9、§5、§6.1、§6.2、§6.5）。本计划只覆盖 P0–P2；选择系统（§3.10）与文档收尾是后续计划。

**先决条件：** 工作区干净、`git log -1` 为 `ea92326` 或其后；已跑过一次 `cd apps/client_flutter && flutter test` 全绿（基线 923 通过 / 5 跳过）。

---

## 文件结构

**新增**

| 文件 | 职责 |
|---|---|
| `apps/client_flutter/assets/rules/dnd5e-2024.rules.json` | 内置档案：abilities / skills / progressions / classes。**只含数值**，无任何规则书正文 |
| `apps/client_flutter/lib/src/features/rules/domain/rule_math.dart` | 纯运算：`abilityModifier`、`proficiencyBonus`、`formatModifier`。唯一的公式来源 |
| `apps/client_flutter/lib/src/features/rules/domain/rule_values.dart` | `IntTable`（`Table<int>`）、`SlotTable`（`Table<{环阶:数量}>`）、`MaxSpec`（value/formula/table） |
| `apps/client_flutter/lib/src/features/rules/domain/rule_diagnostic.dart` | `RuleDiagnostic` / `RuleSeverity`：`{path, severity, code, message}` |
| `apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart` | `ClassRuleSet`（hitDie / savingThrowAbilities / spellcasting / resources 四项数值）、`ClassSpellcasting`、`ClassResourceRule` |
| `apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart` | `RuleProfile`（abilities/skills/progressions/classes + `fieldSources`）、`RuleFieldSource`、按 slug/aliases 查询 |
| `apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart` | 解析 + 校验 + 字段级合并（条目优先）；内置 slug 保护校验 |
| `apps/client_flutter/lib/src/features/rules/data/rule_profile_store.dart` | 读内置档案资产 → `RuleProfileResolver` → `Dnd5eRules.configure` |
| `apps/client_flutter/test/rules/rule_values_test.dart` | `IntTable` / `SlotTable` / `MaxSpec` 单元测试 |
| `apps/client_flutter/test/rules/rule_profile_resolver_test.dart` | 解析、校验、字段级合并测试 |
| `apps/client_flutter/test/rules/builtin_rule_profile_test.dart` | 内置档案对照 SRD 5.2 官方表的核算测试（替代现有硬编码核算） |
| `apps/client_flutter/test/rules/rule_profile_test_support.dart` | 从仓库路径读档案构造 profile 的测试辅助 |

**修改**

| 文件 | 变化 |
|---|---|
| `apps/client_flutter/pubspec.yaml` | assets 增加 `assets/rules/dnd5e-2024.rules.json` |
| `apps/client_flutter/lib/main.dart` | `main()` 改 async，先 `await RuleProfileStore.initialize()` 再 `runApp` |
| `apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart` | **删除** `_hitDice` / `_classSavingThrows` / `_fullCasterSlots` / `_prepared*` / `_secondWindUses` / `_rageUses` / 全部 `contains` 职业匹配；表查询改读 `profile`；纯运算委托 `rule_math.dart` |
| `apps/client_flutter/lib/src/features/characters/domain/structured_class_rules.dart` | 只认 `structured.classRules` 的数值声明；技能选择改由 `rules.choices` 承担（删除 `StructuredSkillChoice`、散文解析正则与 `_validSkills` 静默丢弃） |
| `apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart` | 合并 `条目 classRules ∪ 档案(profile)`；写 `data.classIdentity`；`hitPoints` / `ability` grant 参与派生 |
| `apps/client_flutter/lib/src/features/characters/domain/quick_build.dart` | 用档案 + 条目；写 `classIdentity`；删除 `_saves` 硬编码表 |
| `apps/client_flutter/lib/src/features/characters/domain/character.dart` | `classResources` 按 `classIdentity.slug` 读档案 |
| `apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart` | 老角色按 slug/name/aliases **精确匹配**回填 `classIdentity` |
| `apps/client_flutter/lib/src/features/characters/domain/spell_selection_policy.dart` | 从 `ClassSpellcasting` 的表读取，不再读四列行数组 |
| `apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart` | `_slotMaximums()` 兜底读档案 |
| `apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart` | 法术/资源摘要读档案 |
| `apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart` | `RuleGrantKind` 收敛为 9 项（移除 `resource` / `conditionResistance` / `note`） |
| `apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart` | 接入 `RuleProfileResolver.validateEntry` |
| `apps/client_flutter/lib/src/features/content/domain/content_import_report.dart` | 新增 `warnings` |
| `apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart` | 次级样式展示 warnings |
| `scripts/extract_phb_2024_v2.py` | 输出新契约形状；删除脚本内重复的法术位表 |
| `scripts/test_phb_2024_v2_tools.py` | 断言新形状 |
| `apps/client_flutter/test/dnd5e_rules_verification_test.dart` | 改为对内置档案断言（保留全部官方表期望值） |

**不修改**：Drift schema（`schemaVersion` 保持 13）、服务端任何代码、`DESIGN.md`。

---

## 任务 1：内置档案与资产测试

**文件：**
- 创建：`apps/client_flutter/assets/rules/dnd5e-2024.rules.json`
- 修改：`apps/client_flutter/pubspec.yaml:76-78`
- 测试：`apps/client_flutter/test/rules/builtin_rule_profile_test.dart`

- [ ] **步骤 1：写档案文件（先写 6 个属性 + 18 技能 + 5 个原型 + 12 个职业）**

```jsonc
{
  "rulebookVersion": 1,
  "system": "dnd5e-2024",
  "abilities": ["str", "dex", "con", "int", "wis", "cha"],
  "skills": [
    {"name": "杂技", "ability": "dex"}, {"name": "驯兽", "ability": "wis"},
    {"name": "奥秘", "ability": "int"}, {"name": "运动", "ability": "str"},
    {"name": "欺瞒", "ability": "cha"}, {"name": "历史", "ability": "int"},
    {"name": "洞悉", "ability": "wis"}, {"name": "威吓", "ability": "cha"},
    {"name": "调查", "ability": "int"}, {"name": "医药", "ability": "wis"},
    {"name": "自然", "ability": "int"}, {"name": "察觉", "ability": "wis"},
    {"name": "表演", "ability": "cha"}, {"name": "说服", "ability": "cha"},
    {"name": "宗教", "ability": "int"}, {"name": "巧手", "ability": "dex"},
    {"name": "隐匿", "ability": "dex"}, {"name": "求生", "ability": "wis"}
  ],
  "progressions": {
    "none": {"slots": []},
    "full-caster": {
      "slots": [[2],[3],[4,2],[4,3],[4,3,2],[4,3,3],[4,3,3,1],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,2],
                [4,3,3,3,2,1],[4,3,3,3,2,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1],[4,3,3,3,2,1,1,1],
                [4,3,3,3,2,1,1,1],[4,3,3,3,2,1,1,1,1],[4,3,3,3,3,1,1,1,1],[4,3,3,3,3,2,1,1,1],
                [4,3,3,3,3,2,2,1,1]],
      "maximumSpellLevel": [1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,9,9]
    },
    "half-caster": {
      "minimumLevel": 1,
      "slots": [[2],[2],[3],[3],[4,2],[4,2],[4,3],[4,3],[4,3,2],[4,3,2],[4,3,3],[4,3,3],
                [4,3,3,1],[4,3,3,1],[4,3,3,2],[4,3,3,2],[4,3,3,3,1],[4,3,3,3,1],[4,3,3,3,2],[4,3,3,3,2]],
      "maximumSpellLevel": [1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5]
    },
    "third-caster": {
      "minimumLevel": 3,
      "slots": [[],[],[2],[3],[3],[3],[4,2],[4,2],[4,2],[4,3],[4,3],[4,3],[4,3,2],[4,3,2],[4,3,2],
                [4,3,3],[4,3,3],[4,3,3],[4,3,3,1],[4,3,3,1]],
      "maximumSpellLevel": [0,0,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,3,4,4]
    },
    "pact": {
      "minimumLevel": 1,
      "slots": [[1],[2],[2],[2],[2],[2],[2],[2],[2],[2],[3],[3],[3],[3],[3],[3],[4],[4],[4],[4]],
      "slotLevel": [1,1,2,2,3,3,4,4,5,5,5,5,5,5,5,5,5,5,5,5],
      "maximumSpellLevel": [1,1,2,2,3,3,4,4,5,5,5,5,5,5,5,5,5,5,5,5]
    }
  },
  "classes": { "…任务 1 步骤 2…": {} }
}
```

> 原型内部的 `slots` / `maximumSpellLevel` 必须是**完整 20 项数组**（模板）。
> **原型不承载 `prepared` / `cantrips`**——这两列 2024 官方表逐职业不同（法师 20 级 25、术士 1 级 2…），
> 必须写在各职业自己的 `spellcasting` 里；放进原型会让法师从 25 静默掉到 22。
> 数值来源：SRD 5.2 各职业 Features 表（本轮审计已逐项核对，见 `dnd5e_rules_verification_test.dart` 现有期望值）。

- [ ] **步骤 2：补全 `classes`（12 个核心 slug）**

按下面事实填 12 项。**档案只含数值**：`hitDie` / `savingThrowAbilities` / `spellcasting` / `resources`
（技能选择、法术选择、特性都属于"选择与效果"，由内容条目的 `rules` 声明，不写进档案）：

```jsonc
"barbarian": { "hitDie": 12, "savingThrowAbilities": ["str","con"],
  "spellcasting": {"mode": "none"},
  "resources": [{"id":"rage","name":"狂暴","recovery":"shortRestOne",
    "maximum":{"table":{"1":2,"3":3,"6":4,"12":5,"17":6}}}] },
"fighter": { "hitDie": 10, "savingThrowAbilities": ["str","con"],
  "spellcasting": {"mode": "none"},
  "resources": [
    {"id":"second_wind","name":"第二气息","recovery":"shortRestOne",
     "maximum":{"table":{"1":2,"4":3,"10":4}}},
    {"id":"action_surge","name":"动作如潮","startsAtLevel":2,"recovery":"shortRest",
     "maximum":{"table":{"2":1,"17":2}}}] }
```

其余 10 个职业的完整数据（**资源池数值已按 SRD 5.2 原文逐条核对**，注意恢复语义有四种）：

**法术位进阶（`archetype`）**：吟游诗人/牧师/德鲁伊/术士/法师 = `full-caster`；圣武士/游侠 = `half-caster`；
邪术师 = `pact`；野蛮人/战士/武僧/游荡者 = `{"mode":"none"}`。

**`prepared` 与 `cantrips` 逐职业写在自己的 `spellcasting` 里**（下表已按 SRD 5.2 逐项核对，20 项数组）：

| slug | prepared（1→20 级） | cantrips（1→20 级） |
|---|---|---|
| bard | 4,5,6,7,9,10,11,12,14,15,16,16,17,17,18,18,19,20,21,22 | 2,2,2,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4 |
| cleric | 4,5,6,7,9,10,11,12,14,15,16,16,17,17,18,18,19,20,21,22 | 3,3,3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5 |
| druid | 4,5,6,7,9,10,11,12,14,15,16,16,17,17,18,18,19,20,21,22 | 2,2,2,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4 |
| sorcerer | **2,4,6,7,9,10,11,12,14,15,16,16,17,17,18,18,19,20,21,22** | **4,4,4,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6** |
| wizard | **4,5,6,7,9,10,11,12,14,15,16,16,17,18,19,21,22,23,24,25** | 3,3,3,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5 |
| paladin | 2,3,4,5,6,6,7,7,9,9,10,10,11,11,12,12,14,14,15,15 | 0 × 20 |
| ranger | 2,3,4,5,6,6,7,7,9,9,10,10,11,11,12,12,14,14,15,15 | 0 × 20 |
| warlock | 2,3,4,5,6,7,8,9,10,10,11,11,12,12,13,13,14,14,15,15 | 2,2,2,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4 |
| fighter/barbarian/monk/rogue | 非施法者，不写 | — |

> 加粗处就是"不能塞进原型"的证明：术士 1 级只要 2 个准备法术、法师 20 级要到 25 个。
> `third-caster`（奥法骑士/诡术师）**没有** `prepared`/`cantrips`（2024 职业表未给出这两列，不臆造）。

| slug | hitDie | saves | resources（id / name / maximum / recovery / startsAtLevel） |
|---|---|---|---|
| bard | 8 | dex, cha | `bardic_inspiration` 诗人激励 `{"formula":"ability:cha","minimum":1}` / `{"table":{"1":"longRest","5":"shortRest"}}` / 1 |
| cleric | 8 | wis, cha | `channel_divinity` 引导神力 `{"table":{"2":2,"6":3,"18":4}}` / `shortRestOne` / 2 |
| druid | 8 | int, wis | `wild_shape` 野性形态 `{"table":{"2":2,"6":3,"17":4}}` / `shortRestOne` / 2 |
| monk | 8 | dex, wis | `focus_points` 专注点 `{"formula":"level"}` / `shortRest` / 2 |
| paladin | 10 | wis, cha | `channel_divinity` 引导神力 `{"table":{"3":2,"11":3}}` / `shortRestOne` / 3；`lay_on_hands` 圣疗（治疗池）`{"formula":"5*level"}` / `longRest` / 1 |
| ranger | 10 | dex, str | `favored_enemy` 宿敌 `{"table":{"1":2,"5":3,"9":4,"13":5,"17":6}}` / `longRest` / 1 |
| rogue | 8 | dex, int | — |
| sorcerer | 6 | con, cha | `sorcery_points` 术法点 `{"formula":"level"}` / `longRest` / 2；`innate_sorcery` 先天术法 `2` / `longRest` / 2 |
| warlock | 8 | wis, cha | `magical_cunning` 魔法诡计 `1` / `longRest` / 2 |
| wizard | 6 | int, wis | — |

> 关键事实（易写错，已核对原文）：**诗人激励 = 魅力调整值（最低 1）且长休恢复，5 级"激发灵感"改为短休也全恢复**；
> **引导神力（牧师/圣武士）与野性形态都是短休只恢复 1 次**；**先天术法是长休恢复**（不是短休 1 次）；
> **专注点/术法点上限等于职业等级**；**圣疗是 5×等级的治疗池**（不是"次数"）。

> 12 个核心 slug 因此只声明"数值事实"；技能选择等由私有包（任务 10 的提取器）声明，
> 示范做法见 `samples/homebrew-astral-knight/entries.json`。

- [ ] **步骤 3：登记资产**

```yaml
  assets:
    - assets/bundled_content.json
    - assets/branding/ohmydungeon_icon.png
    - assets/rules/dnd5e-2024.rules.json
```

- [ ] **步骤 4：写资产测试（先失败）**

```dart
// test/rules/builtin_rule_profile_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> readArchive() => jsonDecode(
      File('assets/rules/dnd5e-2024.rules.json').readAsStringSync(),
    ) as Map<String, Object?>;

void main() {
  final archive = readArchive();
  final classes = archive['classes']! as Map<String, Object?>;

  test('档案版本与参照清单完整', () {
    expect(archive['rulebookVersion'], 1);
    expect(archive['abilities'], hasLength(6));
    expect(archive['skills'], hasLength(18));
  });

  test('12 个核心职业全部存在且字段合法', () {
    const slugs = ['barbarian','bard','cleric','druid','fighter','monk',
                   'paladin','ranger','rogue','sorcerer','warlock','wizard'];
    for (final slug in slugs) {
      expect(classes.containsKey(slug), isTrue, reason: slug);
      final rules = classes[slug]! as Map<String, Object?>;
      expect(rules['hitDie'], isA<int>(), reason: slug);
      expect(rules['savingThrowAbilities'], hasLength(2), reason: slug);
    }
  });

  test('class 对象只允许契约字段（防止混入散文/多余键）', () {
    const allowed = {'hitDie', 'savingThrowAbilities', 'spellcasting', 'resources'};
    classes.forEach((slug, value) {
      final rules = value! as Map<String, Object?>;
      final extra = rules.keys.toSet().difference(allowed);
      expect(extra, isEmpty, reason: '$slug 出现契约外字段：$extra');
    });
  });

  test('third-caster 的最高环阶由法术位表推导', () {
    final third = (archive['progressions']! as Map)['third-caster']! as Map;
    expect(third['maximumSpellLevel'], [0,0,1,1,1,1,2,2,2,2,2,2,3,3,3,3,3,3,4,4]);
  });

  test('生命骰与豁免对照 SRD 5.2', () {
    const expected = {
      'barbarian': [12, ['str','con']], 'bard': [8, ['dex','cha']],
      'cleric': [8, ['wis','cha']], 'druid': [8, ['int','wis']],
      'fighter': [10, ['str','con']], 'monk': [8, ['dex','wis']],
      'paladin': [10, ['wis','cha']], 'ranger': [10, ['dex','str']],
      'rogue': [8, ['dex','int']], 'sorcerer': [6, ['con','cha']],
      'warlock': [8, ['wis','cha']], 'wizard': [6, ['int','wis']],
    };
    expected.forEach((slug, value) {
      final rules = classes[slug]! as Map<String, Object?>;
      expect(rules['hitDie'], value[0], reason: slug);
      expect(rules['savingThrowAbilities'], value[1], reason: slug);
    });
  });

  test('12 职业资源池的 id 与恢复语义（四种恢复形式都要覆盖）', () {
    Map<String, Object?> resource(String slug, String id) {
      final list = (classes[slug]! as Map)['resources']! as List;
      return list.cast<Map>().firstWhere((r) => r['id'] == id).cast<String, Object?>();
    }

    // shortRest / shortRestOne / longRest / 随等级变化的表，各至少一例
    expect(resource('fighter', 'action_surge')['recovery'], 'shortRest');
    expect(resource('barbarian', 'rage')['recovery'], 'shortRestOne');
    expect(resource('cleric', 'channel_divinity')['recovery'], 'shortRestOne',
        reason: '牧师引导神力短休只恢复 1 次');
    expect(resource('druid', 'wild_shape')['recovery'], 'shortRestOne');
    expect(resource('sorcerer', 'innate_sorcery')['recovery'], 'longRest',
        reason: '先天术法是长休恢复');
    expect(resource('ranger', 'favored_enemy')['recovery'], 'longRest');
    expect((resource('bard', 'bardic_inspiration')['recovery']! as Map)['table'],
        {'1': 'longRest', '5': 'shortRest'},
        reason: '诗人激励 5 级激发灵感后短休也能全恢复');
    expect(resource('monk', 'focus_points')['startsAtLevel'], 2);
    expect(resource('paladin', 'channel_divinity')['startsAtLevel'], 3);
    expect(resource('warlock', 'magical_cunning')['maximum'], 1);
    expect(resource('paladin', 'lay_on_hands')['maximum'], {'formula': '5*level'});
  });

  test('资源池覆盖 12 个职业（除游荡者与法师外都有）', () {
    const withResources = ['barbarian','bard','cleric','druid','fighter','monk',
                           'paladin','ranger','sorcerer','warlock'];
    for (final slug in withResources) {
      expect(((classes[slug]! as Map)['resources']! as List), isNotEmpty, reason: slug);
    }
    for (final slug in ['rogue', 'wizard']) {
      expect((classes[slug]! as Map)['resources'], anyOf(isNull, isEmpty), reason: slug);
    }
  });

  test('每个原型的关键表长度都是 20 或为空', () {
    final progressions = archive['progressions']! as Map<String, Object?>;
    progressions.forEach((name, raw) {
      final p = raw! as Map<String, Object?>;
      for (final key in ['slots','prepared','cantrips','maximumSpellLevel','slotLevel']) {
        final value = p[key];
        if (value == null) continue;
        expect((value as List), hasLength(20), reason: '$name.$key');
      }
    });
  });
}
```

- [ ] **步骤 5：运行测试**

运行：`cd apps/client_flutter && flutter test test/rules/builtin_rule_profile_test.dart`
预期：PASS（步骤 1–3 已写完档案）。若某职业字段缺失则 FAIL 并指出 slug。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/assets/rules/dnd5e-2024.rules.json apps/client_flutter/pubspec.yaml apps/client_flutter/test/rules/builtin_rule_profile_test.dart
git commit -m "feat(rules): 新增内置规则档案与官方表核算测试"
```

---

## 任务 2：`Table` 与 `MaxSpec` 值对象

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_math.dart`
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_values.dart`
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_diagnostic.dart`
- 测试：`apps/client_flutter/test/rules/rule_values_test.dart`

- [ ] **步骤 1：写 `rule_math.dart`（纯运算，唯一公式来源）**

```dart
/// D&D 2024 纯运算。`Dnd5eRules` 的同名方法委托到这里，保证只有一份公式。
int abilityModifier(int score) => ((score - 10) / 2).floor();

int proficiencyBonus(int level) {
  final clamped = level.clamp(1, 20);
  return ((clamped - 1) ~/ 4) + 2;
}

String formatModifier(int modifier) => modifier >= 0 ? '+$modifier' : '$modifier';
```

- [ ] **步骤 2：写 `rule_diagnostic.dart`**

```dart
enum RuleSeverity { error, warning }

class RuleDiagnostic {
  const RuleDiagnostic({
    required this.path,
    required this.severity,
    required this.code,
    required this.message,
  });

  final String path;
  final RuleSeverity severity;
  final String code;
  final String message;

  @override
  String toString() => '[$severity/$code] $path: $message';
}
```

- [ ] **步骤 3：写失败测试**

```dart
// test/rules/rule_values_test.dart
import 'package:dnd_table_client/src/features/rules/domain/rule_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntTable', () {
    test('完整 20 项数组', () {
      final table = IntTable.tryParse(List.generate(20, (i) => i + 1))!;
      expect(table.minLevel, 1);
      expect(table.maxLevel, 20);
      expect(table.at(1), 1);
      expect(table.at(20), 20);
    });

    test('短数组合法：只声明 1..3 级，4 级以上沿用最后值', () {
      final table = IntTable.tryParse([3, 4, 5])!;
      expect(table.at(1), 3);
      expect(table.at(3), 5);
      expect(table.at(9), 5, reason: '高于最后声明等级 → 沿用');
      expect(table.at(20), 5);
    });

    test('稀疏表：高于最后声明沿用，低于最早声明为未声明', () {
      final table = IntTable.tryParse({'5': 7, '9': 11})!;
      expect(table.at(4), isNull, reason: '低于最早声明 → 未声明（不借用 5 级的值）');
      expect(table.at(5), 7);
      expect(table.at(8), 7);
      expect(table.at(9), 11);
      expect(table.at(20), 11);
    });

    test('非法输入返回 null', () {
      expect(IntTable.tryParse([]), isNull);
      expect(IntTable.tryParse(List.filled(21, 1)), isNull);
      expect(IntTable.tryParse({'0': 1}), isNull);
      expect(IntTable.tryParse({'1': -1}), isNull);
      expect(IntTable.tryParse('nope'), isNull);
    });
  });

  group('SlotTable', () {
    test('稀疏表：未声明等级为 null，高于最后声明沿用', () {
      final table = SlotTable.tryParse({'5': {'1': 4, '2': 2}})!;
      expect(table.at(5), {'1': 4, '2': 2});
      expect(table.at(4), isNull, reason: '低于最早声明 → 未声明');
      expect(table.at(9), {'1': 4, '2': 2}, reason: '高于最后声明 → 沿用');
    });

    test('短数组合法', () {
      final table = SlotTable.tryParse([{'1': 2}, {'1': 3}, {'1': 3}])!;
      expect(table.at(1), {'1': 2});
      expect(table.at(3), {'1': 3});
      expect(table.at(20), {'1': 3});
    });

    test('非法环阶与负值返回 null', () {
      expect(SlotTable.tryParse({'1': {'0': 1}}), isNull);
      expect(SlotTable.tryParse({'1': {'10': 1}}), isNull);
      expect(SlotTable.tryParse({'1': {'1': -1}}), isNull);
      expect(SlotTable.tryParse({'21': {'1': 1}}), isNull);
    });
  });

  group('MaxSpec', () {
    const abilities = {'str': 8, 'dex': 10, 'con': 14, 'int': 12, 'wis': 16, 'cha': 20};

    test('整数固定值', () {
      expect(MaxSpec.tryParse(3)!.resolve(level: 5, abilities: abilities), 3);
      expect(MaxSpec.tryParse({'value': 3}), isNull, reason: '没有 {"value": n} 这种写法');
    });

    test('等级与系数×等级', () {
      expect(MaxSpec.tryParse({'formula': 'level'})!.resolve(level: 7, abilities: abilities), 7);
      expect(MaxSpec.tryParse({'formula': '5*level'})!.resolve(level: 4, abilities: abilities), 20);
    });

    test('属性调整值与 minimum 下限', () {
      final cha = MaxSpec.tryParse({'formula': 'ability:cha'})!;
      expect(cha.resolve(level: 1, abilities: abilities), 5);
      final wis = MaxSpec.tryParse({'formula': 'ability:wis', 'minimum': 1})!;
      expect(wis.resolve(level: 1, abilities: abilities), 3);
      final str = MaxSpec.tryParse({'formula': 'ability:str', 'minimum': 1})!;
      expect(str.resolve(level: 1, abilities: abilities), 1);
    });

    test('等级表：稀疏、短数组、向上沿用', () {
      final sparse = MaxSpec.tryParse({'table': {'1': 2, '17': 6}})!;
      expect(sparse.resolve(level: 10, abilities: abilities), 2);
      expect(sparse.resolve(level: 17, abilities: abilities), 6);
      expect(sparse.resolve(level: 20, abilities: abilities), 6);
      final short = MaxSpec.tryParse({'table': [2, 2, 3]})!;
      expect(short.resolve(level: 20, abilities: abilities), 3);
    });

    test('表未声明的等级返回 null 而不是 0（§3.12）', () {
      final sparse = MaxSpec.tryParse({'table': {'3': 1, '7': 2}})!;
      expect(sparse.resolve(level: 2, abilities: abilities), isNull,
          reason: '低于最早声明等级 → 未声明，不得成为 0 次');
      expect(sparse.resolve(level: 3, abilities: abilities), 1);
      // 显式写 0 与"未声明"语义不同：0 表示存在但上限为 0
      final zero = MaxSpec.tryParse({'table': {'1': 0, '5': 2}})!;
      expect(zero.resolve(level: 1, abilities: abilities), 0);
      expect(zero.resolve(level: 4, abilities: abilities), 0);
    });

    test('封闭语法之外一律拒绝', () {
      for (final bad in ['prof', 'level*2', 'ability', 'ability:luck', '1+1', '']) {
        expect(MaxSpec.tryParse({'formula': bad}), isNull, reason: bad);
      }
      expect(MaxSpec.tryParse({'formula': 'level', 'table': {'1': 1}}), isNull); // 同时给两种
      expect(MaxSpec.tryParse({'formula': 'level', 'minimum': -1}), isNull);
      expect(MaxSpec.tryParse(null), isNull);
    });
  });
}
```

- [ ] **步骤 4：运行测试确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/rule_values_test.dart`
预期：FAIL，`Error: Not found: 'package:dnd_table_client/src/features/rules/domain/rule_values.dart'`

- [ ] **步骤 5：实现 `rule_values.dart`**

```dart
import 'rule_math.dart';

/// `Table<int>`：长度 ≤20 的数组，或稀疏 `{"<等级>": 值}`（键 1..20）。
/// 取值语义（§3.12）：高于最后声明等级 → 沿用最后声明值；低于最早声明等级 → null（未声明）。
class IntTable {
  const IntTable._(this._byLevel, this.minLevel, this.maxLevel);

  final Map<int, int> _byLevel;
  final int minLevel;
  final int maxLevel;

  static IntTable? tryParse(Object? raw) {
    final byLevel = _expandInt(raw);
    if (byLevel == null || byLevel.isEmpty) return null;
    if (byLevel.values.any((value) => value < 0)) return null;
    final levels = byLevel.keys.toList()..sort();
    return IntTable._(byLevel, levels.first, levels.last);
  }

  int? at(int level) {
    if (level < minLevel) return null;              // 未声明，交由 archetype 回退
    return _byLevel[level] ?? _byLevel[maxLevel]!;  // 高于已声明 → 沿用最后一个
  }
}

/// `Table<{环阶: 数量}>`：法术位。整级替换语义 + §3.12 的两条取值规则。
class SlotTable {
  const SlotTable._(this._byLevel, this.minLevel, this.maxLevel);

  final Map<int, Map<String, int>> _byLevel;
  final int minLevel;
  final int maxLevel;

  static SlotTable? tryParse(Object? raw) {
    final byLevel = <int, Map<String, int>>{};
    if (raw is List) {
      if (raw.isEmpty || raw.length > 20) return null;
      for (var index = 0; index < raw.length; index++) {
        final parsed = _slots(raw[index], index + 1);
        if (parsed == null) return null;
        byLevel[index + 1] = parsed;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        if (level == null || level < 1 || level > 20) return null; // 未知键一律拒绝
        final parsed = _slots(entry.value, level);
        if (parsed == null) return null;
        byLevel[level] = parsed;
      }
    } else {
      return null;
    }
    if (byLevel.isEmpty) return null;
    final levels = byLevel.keys.toList()..sort();
    return SlotTable._(byLevel, levels.first, levels.last);
  }

  static Map<String, int>? _slots(Object? raw, int level) {
    if (raw == null) return const <String, int>{};
    if (raw is! Map) return null;
    final slots = <String, int>{};
    for (final slot in raw.entries) {
      final slotLevel = int.tryParse('${slot.key}');
      final count = slot.value is num ? (slot.value! as num).toInt() : null;
      if (slotLevel == null || slotLevel < 1 || slotLevel > 9) return null;
      if (count == null || count < 0) return null;
      if (count > 0) slots['$slotLevel'] = count;
    }
    return slots;
  }

  /// null = 该等级未声明（低于最早声明等级），交由 archetype 回退。
  Map<String, int>? at(int level) {
    if (level < minLevel) return null;
    return _byLevel[level] ?? _byLevel[maxLevel]!;
  }
}

/// `Table<String>`：与 [IntTable] 同一套"常量或表"语义，用于随等级变化的枚举值（如 `recovery`）。
class StringTable {
  const StringTable._(this._byLevel, this.minLevel, this.maxLevel);

  final Map<int, String> _byLevel;
  final int minLevel;
  final int maxLevel;

  static StringTable? tryParse(Object? raw, Set<String> allowed) {
    final result = <int, String>{};
    if (raw is List) {
      if (raw.isEmpty || raw.length > 20) return null;
      for (var index = 0; index < raw.length; index++) {
        final value = '${raw[index]}'.trim();
        if (!allowed.contains(value)) return null;
        result[index + 1] = value;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final level = int.tryParse('${entry.key}');
        final value = '${entry.value}'.trim();
        if (level == null || level < 1 || level > 20) return null;
        if (!allowed.contains(value)) return null;
        result[level] = value;
      }
    } else {
      return null;
    }
    if (result.isEmpty) return null;
    final levels = result.keys.toList()..sort();
    return StringTable._(result, levels.first, levels.last);
  }

  String? at(int level) {
    if (level < minLevel) return null;
    return _byLevel[level] ?? _byLevel[maxLevel]!;
  }
}

/// 资源上限：整数，或 `{"formula": "…"}` / `{"table": <Table<int>>}`，对象形态可带 `minimum`。
class MaxSpec {
  const MaxSpec._({this.value, this.formula, this.table, this.minimum});

  final int? value;
  final String? formula;
  final IntTable? table;
  final int? minimum;

  static MaxSpec? tryParse(Object? raw) {
    if (raw is num) {
      final value = raw.toInt();
      return value < 0 ? null : MaxSpec._(value: value);
    }
    if (raw is! Map) return null;
    final minimum = raw['minimum'] is num ? (raw['minimum']! as num).toInt() : null;
    if (minimum != null && minimum < 0) return null;
    final hasFormula = raw.containsKey('formula');
    final hasTable = raw.containsKey('table');
    final kinds = [hasFormula, hasTable].where((flag) => flag).length;
    if (kinds != 1) return null;
    if (raw.containsKey('value')) return null; // 已废弃的写法，明确拒绝
    if (hasFormula) {
      final formula = raw['formula'];
      if (formula is! String || !isSupportedFormula(formula)) return null;
      return MaxSpec._(formula: formula, minimum: minimum);
    }
    final table = IntTable.tryParse(raw['table']);
    if (table == null) return null;
    return MaxSpec._(table: table, minimum: minimum);
  }

  /// 返回 `int?`：表在该等级**未声明**时返回 null（调用方跳过），不静默变 0（§3.12）。
  int? resolve({required int level, required Map<String, int> abilities}) {
    final raw = switch (this) {
      MaxSpec(value: final v?) => v,
      MaxSpec(formula: final f?) => _evaluate(f, level, abilities),
      _ => table!.at(level),
    };
    if (raw == null) return null;
    return minimum == null || raw >= minimum! ? raw : minimum!;
  }
}

const _formulaPattern = r'^(level|ability:[a-z]{3}|(\d+)\*level|(\d+))$';

bool isSupportedFormula(String formula) =>
    RegExp(_formulaPattern).hasMatch(formula);

int _evaluate(String formula, int level, Map<String, int> abilities) {
  if (formula == 'level') return level;
  if (formula.startsWith('ability:')) {
    return abilityModifier(abilities[formula.substring(8)] ?? 10);
  }
  if (formula.endsWith('*level')) {
    return int.parse(formula.substring(0, formula.length - 6)) * level;
  }
  return int.parse(formula);
}

/// 解析"长度 ≤20 的数组"或"稀疏 map"；非法输入返回 null。
Map<int, int>? _expandInt(Object? raw) {
  final result = <int, int>{};
  if (raw is List) {
    if (raw.isEmpty || raw.length > 20) return null;
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      if (value is! num) return null;
      result[index + 1] = value.toInt();
    }
    return result;
  }
  if (raw is Map) {
    for (final entry in raw.entries) {
      final level = int.tryParse('${entry.key}');
      if (level == null || level < 1 || level > 20) return null; // 未知键一律拒绝
      final value = entry.value;
      if (value is! num) return null;
      result[level] = value.toInt();
    }
    return result;
  }
  return null;
}
```

- [ ] **步骤 6：运行测试确认通过**

运行：`cd apps/client_flutter && flutter test test/rules/rule_values_test.dart`
预期：PASS（全部用例）

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_math.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_values.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_diagnostic.dart \
        apps/client_flutter/test/rules/rule_values_test.dart
git commit -m "feat(rules): 新增 Table/MaxSpec 值对象与纯运算模块"
```

---

## 任务 3：`ClassRuleSet` 与职业规则解析

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart`
- 测试：`apps/client_flutter/test/rules/rule_profile_resolver_test.dart`（本任务先写其中的 `ClassRuleSet` 部分）

> **补一条校验项（任务 9 审查发现）**：`hitPoints` / `ability` grant 的 `formula` 必须用同一套封闭语法校验，
> 非法 formula 要在**导入期**报 `invalidMaxSpec`（error），而不是像现在这样在运行期静默跳过。

- [ ] **步骤 1：写失败测试**

```dart
// test/rules/rule_profile_resolver_test.dart
import 'package:dnd_table_client/src/features/rules/domain/class_rule_set.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_diagnostic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ClassRuleSet.parse', () {
    test('解析完整职业规则块', () {
      final diagnostics = <RuleDiagnostic>[];
      final rules = ClassRuleSet.parse(
        {
          'hitDie': 10,
          'savingThrowAbilities': ['wis', 'cha'],
          'spellcasting': {
            'mode': 'prepared',
            'ability': 'cha',
            'listTags': ['spell-list:astral'],
            'archetype': 'half-caster',
            'slots': {'5': {'1': 4, '2': 2}},
          },
          'resources': [
            {'id': 'surge', 'name': '星界涌动', 'recovery': 'shortRestOne',
             'maximum': {'formula': 'level'}},
          ],
        },
        path: r'$.structured.classRules',
        diagnostics: diagnostics,
      );

      expect(diagnostics, isEmpty);
      expect(rules.hitDie, 10);
      expect(rules.savingThrowAbilities, {'wis', 'cha'});
      expect(rules.spellcasting!.mode, 'prepared');
      expect(rules.spellcasting!.ability, 'cha');
      expect(rules.spellcasting!.archetype, 'half-caster');
      expect(rules.spellcasting!.slots!.at(5), {'1': 4, '2': 2});
      expect(rules.resources.single.recovery, 'shortRestOne');
      expect(rules.resources.single.maximum.resolve(level: 7, abilities: const {'cha': 16}), 7);
    });

    test('hitDie 只接受整数，dN 字符串被拒绝', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'hitDie': 'd12'},
        path: r'$.structured.classRules',
        diagnostics: diagnostics,
      );
      expect(diagnostics.first.code, 'invalidHitDie');
      expect(diagnostics.first.message, contains('10'));
    });

    test('未知字段报 error 并给出候选', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'hitDices': 10},
        path: r'$.structured.classRules',
        diagnostics: diagnostics,
      );
      final errors =
          diagnostics.where((d) => d.severity == RuleSeverity.error).toList();
      expect(errors.single.code, 'unknownField');
      expect(errors.single.message, contains('hitDie'));
    });

    test('非法生命骰、未知属性、未知技能都报 error', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'hitDie': 7, 'savingThrowAbilities': ['luck']},
        path: r'$.structured.classRules',
        diagnostics: diagnostics,
        abilities: const {'str', 'dex', 'con', 'int', 'wis', 'cha'},
        skills: const {'洞悉', '医药'},
      );
      final codes = diagnostics.map((d) => d.code).toSet();
      expect(codes, containsAll(['invalidHitDie', 'unknownAbility']));
    });

    test('缺 hitDie 给 warning 而不是 error', () {
      final diagnostics = <RuleDiagnostic>[];
      ClassRuleSet.parse(
        {'savingThrowAbilities': ['str']},
        path: r'$.structured.classRules',
        diagnostics: diagnostics,
      );
      expect(diagnostics.single.severity, RuleSeverity.warning);
      expect(diagnostics.single.code, 'missingCoreField');
    });
  });
}
```

- [ ] **步骤 2：运行测试确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_resolver_test.dart`
预期：FAIL，`Not found: '.../class_rule_set.dart'`

- [ ] **步骤 3：实现 `class_rule_set.dart`**

```dart
import 'rule_diagnostic.dart';
import 'rule_values.dart';

const kDefaultAbilities = {'str', 'dex', 'con', 'int', 'wis', 'cha'};
const kDefaultSkills = {
  '杂技','驯兽','奥秘','运动','欺瞒','历史','洞悉','威吓','调查','医药',
  '自然','察觉','表演','说服','宗教','巧手','隐匿','求生',
};

class ClassResourceRule {
  const ClassResourceRule({
    required this.id, required this.name, required this.maximum,
    required this.recovery, this.recoveryTable, this.startsAtLevel = 1,
    this.description,
  });
  final String id;
  final String name;
  final MaxSpec maximum;
  /// 可选的一句话说明（**档案里禁止出现**，见 §3.1；第三方包可用）。
  final String? description;
  /// 常量恢复语义（未随等级变化时）。
  final String recovery;
  /// 随等级变化的恢复语义（如诗人激励 1 级长休、5 级短休）。
  final StringTable? recoveryTable;
  final int startsAtLevel;

  String recoveryAt(int level) => recoveryTable?.at(level) ?? recovery;

  /// 资源表声明到的最高等级；只有 formula 的资源不贡献等级。
  int? get declaredMaxLevel => maximum.table?.maxLevel;
}

class ClassSpellcasting {
  const ClassSpellcasting({
    required this.mode, this.ability, this.listTags = const [],
    this.archetype, this.slots, this.slotLevel, this.prepared,
    this.cantrips, this.maximumSpellLevel,
  });
  final String mode;
  final String? ability;
  final List<String> listTags;
  final String? archetype;
  final SlotTable? slots;
  final IntTable? slotLevel;
  final IntTable? prepared;
  final IntTable? cantrips;
  final IntTable? maximumSpellLevel;

  /// 各表声明到的最高等级（供 declaredMaxLevel 汇总）。
  List<int> get declaredMaxLevels => [
        if (slots != null) slots!.maxLevel,
        if (slotLevel != null) slotLevel!.maxLevel,
        if (prepared != null) prepared!.maxLevel,
        if (cantrips != null) cantrips!.maxLevel,
        if (maximumSpellLevel != null) maximumSpellLevel!.maxLevel,
      ];
}

class ClassRuleSet {
  const ClassRuleSet({
    this.hitDie, this.savingThrowAbilities = const {},
    this.spellcasting, this.resources = const [], this.fields = const {},
  });
  final int? hitDie;
  final Set<String> savingThrowAbilities;
  final ClassSpellcasting? spellcasting;
  final List<ClassResourceRule> resources;
  /// 条目显式声明过的字段名，用于字段级合并。
  final Set<String> fields;

  bool declares(String field) => fields.contains(field);

  /// 该职业**自身**声明的最高等级（§3.12）：取 spellcasting 各表与资源表的最大声明等级。
  /// "只有 formula 的资源"与"没有随等级变化的表"都不贡献，返回 null。
  int? get declaredMaxLevel {
    final levels = <int>[
      ...?spellcasting?.declaredMaxLevels,
      ...resources.map((r) => r.declaredMaxLevel).whereType<int>(),
    ];
    return levels.isEmpty ? null : levels.reduce((a, b) => a > b ? a : b);
  }

  static const _knownFields = {
    'hitDie', 'savingThrowAbilities', 'spellcasting', 'resources',
  };
  static const _spellcastingFields = {
    'mode', 'ability', 'listTags', 'archetype', 'slots', 'slotLevel',
    'prepared', 'cantrips', 'maximumSpellLevel',
  };
  static const _resourceFields = {
    'id', 'name', 'maximum', 'recovery', 'startsAtLevel', 'description',
  };
  /// 标准骰面（生命骰只可能是这五种；d7/d9/d20 一律拒绝）
  static const _hitDieFaces = {4, 6, 8, 10, 12};
  static const _modes = {'prepared', 'known', 'pact', 'none'};
  static const _recoveries = {'shortRest', 'shortRestOne', 'longRest', 'none'};

  static ClassRuleSet parse(
    Map<String, Object?> raw, {
    required String path,
    required List<RuleDiagnostic> diagnostics,
    Set<String> abilities = kDefaultAbilities,
  }) {
    void error(String code, String field, String message) => diagnostics.add(
        RuleDiagnostic(path: '$path.$field', severity: RuleSeverity.error,
            code: code, message: message));
    void warn(String code, String field, String message) => diagnostics.add(
        RuleDiagnostic(path: '$path.$field', severity: RuleSeverity.warning,
            code: code, message: message));

    final fields = <String>{};
    int? hitDie;
    if (raw.containsKey('hitDie')) {
      fields.add('hitDie');
      final value = raw['hitDie'];
      final parsed = value is int ? value : null;
      if (parsed == null || !_hitDieFaces.contains(parsed)) {
        error('invalidHitDie', 'hitDie',
            '生命骰只写整数且必须是标准骰面 4/6/8/10/12，例如 d10 写 10');
      } else {
        hitDie = parsed;
      }
    } else {
      warn('missingCoreField', 'hitDie', '未声明生命骰，角色卡 HP 将按未声明处理');
    }

    final savingThrows = <String>{};
    if (raw.containsKey('savingThrowAbilities')) {
      fields.add('savingThrowAbilities');
      final value = raw['savingThrowAbilities'];
      if (value is! List) {
        error('unknownAbility', 'savingThrowAbilities', '必须是属性键数组');
      } else {
        for (final item in value) {
          final key = '$item'.trim().toLowerCase();
          if (!abilities.contains(key)) {
            error('unknownAbility', 'savingThrowAbilities',
                '未知属性键 "$item"，可用：${abilities.join(', ')}');
          } else {
            savingThrows.add(key);
          }
        }
      }
    }

    ClassSpellcasting? spellcasting;
    if (raw.containsKey('spellcasting')) {
      fields.add('spellcasting');
      final value = raw['spellcasting'];
      if (value is! Map) {
        error('invalidSpellcastingMode', 'spellcasting', '必须是对象');
      } else {
        for (final key in value.keys) {
          if (_spellcastingFields.contains('$key')) continue;
          error('unknownField', 'spellcasting.$key', '未知字段 $key');
        }
        final mode = '${value['mode'] ?? 'none'}'.trim();
        if (!_modes.contains(mode)) {
          error('invalidSpellcastingMode', 'spellcasting.mode',
              'spellcasting.mode 必须是 prepared / known / pact / none');
        }
        final abilityRaw = value['ability'];
        final ability = abilityRaw == null ? null : '$abilityRaw'.trim().toLowerCase();
        if (mode != 'none' && (ability == null || !abilities.contains(ability))) {
          error('unknownAbility', 'spellcasting.ability', '施法属性非法或缺失');
        }
        final listTags = value['listTags'] is List
            ? (value['listTags']! as List).map((item) => '$item').toList(growable: false)
            : const <String>[];
        final archetype = value['archetype'] == null ? null : '${value['archetype']}';

        SlotTable? slots;
        IntTable? slotLevel, prepared, cantrips, maximumSpellLevel;
        for (final entry in {
          'slots': () => slots = SlotTable.tryParse(value['slots']),
          'slotLevel': () => slotLevel = IntTable.tryParse(value['slotLevel']),
          'prepared': () => prepared = IntTable.tryParse(value['prepared']),
          'cantrips': () => cantrips = IntTable.tryParse(value['cantrips']),
          'maximumSpellLevel': () =>
              maximumSpellLevel = IntTable.tryParse(value['maximumSpellLevel']),
        }.entries) {
          if (!value.containsKey(entry.key)) continue;
          entry.value();
          final parsed = switch (entry.key) {
            'slots' => slots, 'slotLevel' => slotLevel, 'prepared' => prepared,
            'cantrips' => cantrips, _ => maximumSpellLevel,
          };
          if (parsed == null) {
            error('invalidTable', 'spellcasting.${entry.key}',
                '${entry.key} 必须是 20 项数组或稀疏 {"等级": 值}');
          }
        }
        spellcasting = ClassSpellcasting(
          mode: mode, ability: ability, listTags: listTags, archetype: archetype,
          slots: slots, slotLevel: slotLevel, prepared: prepared,
          cantrips: cantrips, maximumSpellLevel: maximumSpellLevel,
        );
      }
    }

    final resources = <ClassResourceRule>[];
    if (raw.containsKey('resources')) {
      fields.add('resources');
      final value = raw['resources'];
      if (value is! List) {
        error('invalidMaxSpec', 'resources', '必须是数组');
      } else {
        final seen = <String>{};
        for (var index = 0; index < value.length; index++) {
          final item = value[index];
          final itemPath = '$path.resources[$index]';
          if (item is! Map) {
            diagnostics.add(RuleDiagnostic(path: itemPath,
                severity: RuleSeverity.error, code: 'invalidMaxSpec',
                message: '资源必须是对象'));
            continue;
          }
          for (final key in item.keys) {
            if (_resourceFields.contains('$key')) continue;
            diagnostics.add(RuleDiagnostic(path: '$itemPath.$key',
                severity: RuleSeverity.error, code: 'unknownField',
                message: '未知字段 $key'));
          }
          final id = '${item['id'] ?? ''}'.trim();
          final name = '${item['name'] ?? ''}'.trim();
          if (id.isEmpty || name.isEmpty) {
            diagnostics.add(RuleDiagnostic(path: itemPath,
                severity: RuleSeverity.error, code: 'invalidMaxSpec',
                message: '资源缺少 id 或 name'));
            continue;
          }
          if (!seen.add(id)) {
            diagnostics.add(RuleDiagnostic(path: '$itemPath.id',
                severity: RuleSeverity.error, code: 'duplicateResourceId',
                message: '资源 id "$id" 重复'));
            continue;
          }
          final recoveryRaw = item['recovery'] ?? 'longRest';
          var recovery = 'longRest';
          StringTable? recoveryTable;
          if (recoveryRaw is String) {
            recovery = recoveryRaw.trim();
            if (!_recoveries.contains(recovery)) {
              diagnostics.add(RuleDiagnostic(path: '$itemPath.recovery',
                  severity: RuleSeverity.error, code: 'invalidRecovery',
                  message: 'recovery 必须是 shortRest / shortRestOne / longRest / none'));
              continue;
            }
          } else if (recoveryRaw is Map && recoveryRaw['table'] != null) {
            recoveryTable = StringTable.tryParse(recoveryRaw['table'], _recoveries);
            if (recoveryTable == null) {
              diagnostics.add(RuleDiagnostic(path: '$itemPath.recovery.table',
                  severity: RuleSeverity.error, code: 'invalidRecovery',
                  message: 'recovery 表的值必须是 shortRest / shortRestOne / longRest / none'));
              continue;
            }
            recovery = recoveryTable.at(recoveryTable.minLevel) ?? 'longRest';
          } else {
            diagnostics.add(RuleDiagnostic(path: '$itemPath.recovery',
                severity: RuleSeverity.error, code: 'invalidRecovery',
                message: 'recovery 只接受字符串或 {"table": …}'));
            continue;
          }
          final maximum = MaxSpec.tryParse(item['maximum']);
          if (maximum == null) {
            diagnostics.add(RuleDiagnostic(path: '$itemPath.maximum',
                severity: RuleSeverity.error, code: 'invalidMaxSpec',
                message: 'maximum 必须且只能使用 value / formula / table 之一'));
            continue;
          }
          final startsAt = item['startsAtLevel'] is num
              ? (item['startsAtLevel']! as num).toInt() : 1;
          if (startsAt < 1 || startsAt > 20) {
            diagnostics.add(RuleDiagnostic(path: '$itemPath.startsAtLevel',
                severity: RuleSeverity.error, code: 'invalidTable',
                message: 'startsAtLevel 必须为 1..20'));
            continue;
          }
          resources.add(ClassResourceRule(
              id: id, name: name, maximum: maximum, recovery: recovery,
              recoveryTable: recoveryTable, startsAtLevel: startsAt,
              description: item['description'] == null
                  ? null
                  : '${item['description']}'));
        }
      }
    }

    for (final key in raw.keys) {
      if (_knownFields.contains(key)) continue;
      diagnostics.add(RuleDiagnostic(path: '$path.$key',
          severity: RuleSeverity.error, code: 'unknownField',
          message: '未知字段 $key${_suggestion(key)}'));
    }

    return ClassRuleSet(hitDie: hitDie, savingThrowAbilities: savingThrows,
        spellcasting: spellcasting,
        resources: resources, fields: fields);
  }

  static String _suggestion(String key) {
    const candidates = ['hitDie', 'savingThrowAbilities', 'spellcasting', 'resources'];
    for (final candidate in candidates) {
      if (candidate.toLowerCase().startsWith(key.toLowerCase().substring(0, 3))) {
        return '，是否想写 $candidate？';
      }
    }
    return '';
  }
}
```

- [ ] **步骤 4：运行测试确认通过**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_resolver_test.dart`
预期：PASS

- [ ] **步骤 5：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/class_rule_set.dart apps/client_flutter/test/rules/rule_profile_resolver_test.dart
git commit -m "feat(rules): 职业规则块 ClassRuleSet 与字段级诊断"
```

---

## 任务 4：`RuleProfile` 与 `RuleProfileResolver`

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart`
- 创建：`apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart`
- 修改：`apps/client_flutter/test/rules/rule_profile_resolver_test.dart`（追加 group）

- [ ] **步骤 1：追加失败测试**

```dart
  group('RuleProfileResolver', () {
    Map<String, Object?> archive() => {
      'rulebookVersion': 1,
      'system': 'dnd5e-2024',
      'abilities': ['str', 'dex', 'con', 'int', 'wis', 'cha'],
      'skills': [{'name': '察觉', 'ability': 'wis'}],
      'progressions': {
        'none': {'slots': []},
        'half-caster': {
          'minimumLevel': 1,
          'slots': List.generate(20, (i) => i < 1 ? <String, Object?>{} : {'1': 2}),
          'prepared': [2,3,4,5,6,6,7,7,9,9,10,10,11,11,12,12,14,14,15,15],
          'cantrips': List.filled(20, 0),
          'maximumSpellLevel': List.filled(20, 1),
        },
      },
      'classes': {
        'barbarian': {'hitDie': 12, 'savingThrowAbilities': ['str', 'con']},
      },
    };

    test('解析内置档案并可查询', () {
      final result = RuleProfileResolver.resolveBuiltin(archive());
      expect(result.errors, isEmpty);
      final profile = result.profile!;
      expect(profile.abilities, hasLength(6));
      expect(profile.classRules('barbarian')!.hitDie, 12);
      expect(profile.classRules('BARBARIAN')!.hitDie, 12); // 大小写归一
      expect(profile.classRules('nope'), isNull);
    });

    test('未知原型报 error', () {
      final raw = archive();
      (raw['classes']! as Map)['barbarian'] = {
        'hitDie': 12,
        'spellcasting': {'mode': 'prepared', 'ability': 'wis', 'archetype': 'three-quarter'},
      };
      final result = RuleProfileResolver.resolveBuiltin(raw);
      expect(result.errors.single.code, 'unknownArchetype');
    });

    test('字段级合并：条目优先，档案补齐，并记录来源', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final diagnostics = <RuleDiagnostic>[];
      final merged = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'barbarian',
        entryRules: ClassRuleSet.parse(
          {'savingThrowAbilities': ['dex']},
          path: r'$.structured.classRules',
          diagnostics: diagnostics,
        ),
      );
      expect(merged.hitDie, 12, reason: '档案补齐');
      expect(merged.savingThrowAbilities, {'dex'}, reason: '条目优先，整字段替换');
      expect(merged.fieldSources['hitDie']!.originId, 'builtin:dnd5e-2024');
      expect(merged.fieldSources['savingThrowAbilities']!.originId, '<entry>');
    });

    test('条目完全没有规则时用档案，完全未声明时为空', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final fromArchive = RuleProfileResolver.resolveClassRules(
        profile: profile, slug: 'barbarian', entryRules: null);
      expect(fromArchive.hitDie, 12);
      final unknown = RuleProfileResolver.resolveClassRules(
        profile: profile, slug: 'astral-knight', entryRules: null);
      expect(unknown.hitDie, isNull);
      expect(unknown.savingThrowAbilities, isEmpty);
    });

    test('法术位解析：原型展开 + 整级替换 + minimumLevel', () {
      final profile = RuleProfileResolver.resolveBuiltin(archive()).profile!;
      final half = RuleProfileResolver.resolveClassRules(
          profile: profile, slug: 'barbarian', entryRules: null);
      expect(half.spellcasting, isNull);
      final caster = RuleProfileResolver.resolveClassRules(
        profile: profile,
        slug: 'astral',
        entryRules: ClassRuleSet.parse(
          {'spellcasting': {'mode': 'prepared', 'ability': 'wis',
                            'archetype': 'half-caster', 'slots': {'5': {'1': 9}}}},
          path: r'$.structured.classRules',
          diagnostics: <RuleDiagnostic>[],
        ),
      );
      expect(caster.spellSlots(1), {'1': 2}, reason: '原型展开');
      expect(caster.spellSlots(5), {'1': 9}, reason: '整级替换');
      expect(caster.preparedLimit(5), isNull, reason: '原型不承载 prepared，无回退');
    });
  });
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_resolver_test.dart`
预期：FAIL，`Not found: '.../rule_profile.dart'`

- [ ] **步骤 3：实现 `rule_profile.dart`**

```dart
import 'class_rule_set.dart';
import 'rule_values.dart';

const kBuiltinOriginId = 'builtin:dnd5e-2024';

class RuleFieldSource {
  const RuleFieldSource({required this.field, required this.originId, required this.tier});
  final String field;
  final String originId; // 'builtin:dnd5e-2024' 或条目 id
  final int tier;        // 0 内置档案 / 100 条目声明
}

class ClassProgression {
  const ClassProgression({
    required this.name, this.minimumLevel = 1, this.slots, this.slotLevel,
    this.prepared, this.cantrips, this.maximumSpellLevel,
  });
  final String name;
  final int minimumLevel;
  final SlotTable? slots;
  final IntTable? slotLevel;
  final IntTable? prepared;
  final IntTable? cantrips;
  final IntTable? maximumSpellLevel;
}

class RuleProfile {
  const RuleProfile({
    required this.abilities, required this.skills,
    required this.progressions, required this.classes, this.aliases = const {},
  });
  final Set<String> abilities;
  final Map<String, String> skills; // 技能名 → 属性键
  final Map<String, ClassProgression> progressions;
  final Map<String, ClassRuleSet> classes; // slug（小写）→ 规则
  final Map<String, String> aliases;       // 别名（小写）→ slug

  /// 大小写归一 + 别名回退；未命中返回 null。
  ClassRuleSet? classRules(String key) {
    final normalized = key.trim().toLowerCase();
    return classes[normalized] ?? classes[aliases[normalized]];
  }

  ClassProgression? progression(String? name) =>
      name == null ? null : progressions[name];
}

class ResolvedResource {
  const ResolvedResource({
    required this.id, required this.name, required this.maximum, required this.recovery,
  });
  final String id;
  final String name;
  final int maximum;
  final String recovery;
}

/// 条目声明 ∪ 内置档案（条目优先）后的职业规则。
class ResolvedClassRules {
  const ResolvedClassRules({
    this.hitDie, this.savingThrowAbilities = const {},
    this.spellcasting, this.resources = const [], this.fieldSources = const {},
    this.archetype, this.declaredMaxLevel, this.declaredMinLevel,
  });

  final int? hitDie;
  final Set<String> savingThrowAbilities;
  final ClassSpellcasting? spellcasting;
  final List<ClassResourceRule> resources;
  final ClassProgression? archetype;
  final Map<String, RuleFieldSource> fieldSources;

  /// 职业**自身**声明的最高等级（不含 archetype 模板，§3.12）。
  /// null 表示该职业没有声明任何随等级变化的表（只有特性 progression 也算，见构建器合并）。
  final int? declaredMaxLevel;

  /// 职业**自身**声明的最早等级（§3.12 的 `{min, max}` 里的 min）。
  final int? declaredMinLevel;

  String? get spellcastingAbility => spellcasting?.ability;
  String get spellcastingMode => spellcasting?.mode ?? 'none';

  /// 法术位：自身 slots 表优先（已声明的等级整级替换，哪怕是空表）；
  /// 自身未声明该等级（`at` 返回 null）才回退原型；原型也低于 minimumLevel 则为空。
  Map<String, int> spellSlots(int level) {
    if (spellcastingMode == 'none') return const {};
    final own = spellcasting?.slots?.at(level);
    if (own != null) return own;
    final progression = archetype;
    if (progression == null || level < progression.minimumLevel) return const {};
    return progression.slots?.at(level) ?? const {};
  }

  int? pactSlotLevel(int level) =>
      spellcasting?.slotLevel?.at(level) ?? archetype?.slotLevel?.at(level);

  int? preparedLimit(int level) =>
      _pick(level, (c) => c.prepared, (p) => p.prepared);

  int? cantripLimit(int level) =>
      _pick(level, (c) => c.cantrips, (p) => p.cantrips);

  int? maxSpellLevel(int level) =>
      _pick(level, (c) => c.maximumSpellLevel, (p) => p.maximumSpellLevel);

  int? _pick(int level, IntTable? Function(ClassSpellcasting) own,
             IntTable? Function(ClassProgression) fromArchetype) {
    if (spellcastingMode == 'none') return null;
    if (spellcasting != null) {
      final value = own(spellcasting!)?.at(level);
      if (value != null) return value;   // 已声明该等级（含"高于最后声明沿用"）
    }
    final progression = archetype;
    if (progression == null || level < progression.minimumLevel) return null;
    return fromArchetype(progression)?.at(level);
  }

  /// 未声明该等级上限的资源会被**跳过**（不是产出"上限 0"的假资源，§3.12）。
  List<ResolvedResource> resourcesAt(int level, Map<String, int> abilities) {
    final result = <ResolvedResource>[];
    for (final rule in resources) {
      if (level < rule.startsAtLevel) continue;
      final maximum = rule.maximum.resolve(level: level, abilities: abilities);
      if (maximum == null) continue;
      result.add(ResolvedResource(
        id: rule.id, name: rule.name, recovery: rule.recoveryAt(level),
        maximum: maximum,
      ));
    }
    return result;
  }
}
```

- [ ] **步骤 4：实现 `rule_profile_resolver.dart`**

```dart
import 'class_rule_set.dart';
import 'rule_diagnostic.dart';
import 'rule_profile.dart';
import 'rule_values.dart';

class RuleProfileResolution {
  const RuleProfileResolution({required this.profile, required this.diagnostics});
  final RuleProfile? profile;
  final List<RuleDiagnostic> diagnostics;
  List<RuleDiagnostic> get errors => diagnostics
      .where((d) => d.severity == RuleSeverity.error).toList(growable: false);
  List<RuleDiagnostic> get warnings => diagnostics
      .where((d) => d.severity == RuleSeverity.warning).toList(growable: false);
}

abstract final class RuleProfileResolver {
  static RuleProfileResolution resolveBuiltin(Map<String, Object?> raw) {
    final diagnostics = <RuleDiagnostic>[];
    final abilities = _stringSet(raw['abilities']);
    final skills = <String, String>{};
    if (raw['skills'] is List) {
      for (final item in raw['skills']! as List) {
        if (item is Map) skills['${item['name']}'] = '${item['ability']}';
      }
    }
    final progressions = <String, ClassProgression>{};
    if (raw['progressions'] is Map) {
      (raw['progressions']! as Map).forEach((key, value) {
        if (value is! Map) return;
        final map = Map<String, Object?>.from(value);
        final name = '$key';
        final slots = SlotTable.tryParse(map['slots']);
        if (map['slots'] != null && slots == null) {
          diagnostics.add(RuleDiagnostic(path: r'$.progressions.' + name + '.slots',
              severity: RuleSeverity.error, code: 'invalidTable',
              message: 'slots 必须是 20 项数组'));
        }
        progressions[name] = ClassProgression(
          name: name,
          minimumLevel: map['minimumLevel'] is num
              ? (map['minimumLevel']! as num).toInt() : 1,
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
    if (raw['classes'] is Map) {
      (raw['classes']! as Map).forEach((key, value) {
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
    // 原型存在性校验
    for (final entry in classes.entries) {
      final archetype = entry.value.spellcasting?.archetype;
      if (archetype != null && !progressions.containsKey(archetype)) {
        diagnostics.add(RuleDiagnostic(path: r'$.classes.' + entry.key + '.spellcasting.archetype',
            severity: RuleSeverity.error, code: 'unknownArchetype',
            message: '未知原型 "$archetype"'));
      }
    }
    final failed = diagnostics.any((d) => d.severity == RuleSeverity.error);
    return RuleProfileResolution(
      profile: failed ? null : RuleProfile(
        abilities: abilities.isEmpty ? kDefaultAbilities : abilities,
        skills: skills.isEmpty
            ? {for (final name in kDefaultSkills) name: ''} : skills,
        progressions: progressions, classes: classes, aliases: aliases),
      diagnostics: diagnostics,
    );
  }

  /// 条目声明 ∪ 档案（条目优先，字段级）。
  static ResolvedClassRules resolveClassRules({
    required RuleProfile profile,
    required String slug,
    required ClassRuleSet? entryRules,
    String? entryId,
  }) {
    final fromArchive = profile.classRules(slug);
    final entryOrigin = entryId ?? '<entry>';
    final sources = <String, RuleFieldSource>{};

    T? pick<T>(String field, T? Function(ClassRuleSet) read) {
      final declared = entryRules != null && entryRules.declares(field);
      final value = declared ? read(entryRules) : null;
      if (value != null) {
        sources[field] = RuleFieldSource(field: field, originId: entryOrigin, tier: 100);
        return value;
      }
      final fallback = fromArchive == null ? null : read(fromArchive);
      if (fallback != null) {
        sources[field] = RuleFieldSource(
            field: field, originId: kBuiltinOriginId, tier: 0);
      }
      return fallback;
    }

    final spellcasting = pick('spellcasting', (r) => r.spellcasting);
    return ResolvedClassRules(
      hitDie: pick('hitDie', (r) => r.hitDie),
      savingThrowAbilities: pick('savingThrowAbilities', (r) => r.savingThrowAbilities) ?? const {},
      spellcasting: spellcasting,
      resources: pick('resources', (r) => r.resources) ?? const [],
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
```

- [ ] **步骤 5：运行确认通过**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_resolver_test.dart`
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/domain/rule_profile.dart \
        apps/client_flutter/lib/src/features/rules/domain/rule_profile_resolver.dart \
        apps/client_flutter/test/rules/rule_profile_resolver_test.dart
git commit -m "feat(rules): RuleProfile 与字段级合并解析器"
```

---

## 任务 4.5：任务 4 审查后的收尾清单（**执行任务 5 之前必须完成**）

任务 4 已通过两阶段审查；以下是审查给出的应修项，控制者已逐条裁定，按此落地：

**重要**

1. **`pactSlotLevel` 绕过统一守卫**（`rule_profile.dart`）：它无 `mode == 'none'` 早退、无 `archetype.minimumLevel`、
   手写两级回退，且零测试。改为走已有的 `_pick`：
   `int? pactSlotLevel(int level) => _pick(level, (c) => c.slotLevel, (p) => p.slotLevel);`
2. **`spellcastingAbility` 未按 `mode` 门控**：`mode == 'none'` 时仍返回 ability。
   改为 `spellcastingMode == 'none' ? null : spellcasting?.ability`（与 §3.6 第 3 步一致）。
3. **`resolveBuiltin` 94 行、≥4 职责**：拆成 `_parseSkills` / `_parseProgressions` / `_parseClasses` /
   `_validateArchetypes`，`resolveBuiltin` 只留编排。每个函数 <60 行。
4. **`ClassProgression` 仍携带 `prepared`/`cantrips`**：契约禁止原型承载这两列，但类型上仍可读到
   （`merged.archetype!.prepared`）。**从 `ClassProgression` 删除这两个字段**；并在 `resolveBuiltin` 解析原型时
   对白名单 `{slots, slotLevel, maximumSpellLevel, minimumLevel}` 之外的键报 `unknownField`
   （契约新增，见规格 §3.1）。
5. **补 5 条测试断言**（审查用变异证明这些路径目前无人守护）：
   - `resolveBuiltin` 有 error 时 `profile == null`（现在只断言了 `errors.single.code`）；
   - 档案来源的 `fieldSources[...].tier == 0`（现在只断言了 `originId`）；
   - `maxSpellLevel` 自身稀疏表在低于最早声明等级时回退原型（含 `minimumLevel` 守卫）；
   - `pactSlotLevel` 的三态（`none` / 低于 `minimumLevel` / 正常）；
   - `resourcesAt` 里"表内显式 0"仍以资源形式返回（上限 0，而不是被跳过）。

**次要（顺手清）**

6. **删除两个同名 `pick`**：`ResolvedClassRules._pick` 与 resolver 内的 `pick` 跨文件同名不同义。
   把 resolver 的闭包提成 `_mergeField<T>`（或改名 `_readDeclared`），`ResolvedClassRules._pick` 保留。
7. **`skills`/`abilities` 的回退不要伪造占位**（`rule_profile_resolver.dart:115-117`）：档案缺 `skills`
   或 `skills` 为空数组时，现在回退成 `{每个技能名: ''}`，消费方分不清"属性是空串"与"合法属性"。
   按新契约改为：**档案必须显式声明 `abilities` 与 `skills`**；缺失、为空或类型错误 → `invalidTable` error
   → `profile == null`。删掉伪造回退。
8. **`progressions` / `classes` 及其中单项的类型错误不要静默 return**：补 `invalidTable` error
   （写错一节现在会得到空档案且零诊断）。
9. **`dart format` 不要全仓跑**：本 SDK 的格式化器与仓库现状不一致，会重排 52 个既有文件（CI 只跑
   `flutter analyze` + `flutter test`，不校验格式）。只对自己新增/修改的文件跑。

**同时要修的一处跨任务不一致**

10. 任务 8 的端到端用例里 `expect(rules.preparedLimit(5), 6)` 与本契约（`prepared` 无原型回退、
    `astral-knight` 自带 20 项 `prepared` 表且每级比圣武士 +1）不符 —— 应改为 **7**。
    落地任务 8 时按 `samples/homebrew-astral-knight/entries.json` 的实际数据核对。

---

## 任务 4.6：把原型 `slots` 的展开下沉到解析器（**在任务 5 审查之前完成**）

任务 5 的实现者发现：内置档案里原型 `slots` 用的是模板压缩编码 `[[2],[3],[4,2],…]`，
而已交付的 `SlotTable.tryParse` 只认 `{环阶: 数量}`，导致**真实档案解析恒失败**（4 条 `invalidTable`，
`profile == null`）。它临时把展开做在 `rule_profile_store.dart`（数据层）里才让应用能启动。

**这个位置是错的**：解析/展开属于解析器，数据层只该读资产。按契约新写明的分界修正：

**要做的**

1. 在 `rule_profile_resolver.dart` 里实现原型 `slots` 的展开（契约 §3.1 的"模板压缩编码"）：
   - 普通原型：第 n 项的数组 → `{'1': a1, '2': a2, …}`（下标 +1 即环阶，省略 0 值）；
   - `pact`：每级数组只有计数（通常一个元素），环阶由同级 `slotLevel` 提供 → `{'<slotLevel>': count}`；
   - 形状不合法（非数组 / 项数 >20 / 含非非负整数 / `pact` 缺 `slotLevel`）→ `invalidTable`（error）。
2. **删除 `rule_profile_store.dart` 里的展开桥**：store 只负责"读资产 → 调 `RuleProfileResolver.resolveBuiltin`"。
3. 把 `rule_profile_store_test.dart` 里那几条"展开/非法形状"断言**搬到**
   `rule_profile_resolver_test.dart` 的原型测试组。
4. 顺带核对：`resolveBuiltin` 对原型 `maximumSpellLevel`/`slotLevel` 的解析是否仍走 `IntTable`（完整 20 项数组）不变。

**验收**：`RuleProfileResolver.resolveBuiltin(真实档案)` 在**没有 store 参与**的情况下通过、
`profile != null`；store 文件里不含任何展开/形状判断逻辑（只有读资产与错误包装）。

---

## 任务 5：`RuleProfileStore` 与 `Dnd5eRules.configure`

**文件：**
- 创建：`apps/client_flutter/lib/src/features/rules/data/rule_profile_store.dart`
- 修改：`apps/client_flutter/lib/main.dart`
- 创建：`apps/client_flutter/test/rules/rule_profile_test_support.dart`
- 测试：`apps/client_flutter/test/rules/rule_profile_store_test.dart`

- [ ] **步骤 1：写测试辅助与失败测试**

```dart
// test/rules/rule_profile_test_support.dart
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/rules/domain/rule_profile.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';

/// 从仓库路径读取内置档案（flutter test 的工作目录是包根）。
RuleProfile loadBuiltinProfileForTest() {
  final raw = jsonDecode(
    File('assets/rules/dnd5e-2024.rules.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final result = RuleProfileResolver.resolveBuiltin(raw);
  if (result.profile == null) {
    fail('内置档案解析失败：${result.errors.join('\n')}');
  }
  return result.profile!;
}
```

```dart
// test/rules/rule_profile_store_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/rules/data/rule_profile_store.dart';
import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rule_profile_test_support.dart';

void main() {
  test('内置档案可加载并装配到 Dnd5eRules（不走 rootBundle）', () async {
    final raw = jsonDecode(
      File('assets/rules/dnd5e-2024.rules.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final profile = await RuleProfileStore.loadBuiltin(
      readAsset: (path) async {
        expect(path, RuleProfileStore.assetPath);
        return raw;
      },
    );
    await Dnd5eRules.configure(profile);
    expect(Dnd5eRules.profile.classRules('barbarian')!.hitDie, 12);
  });

  test('未装配或已装配后再次 configure 都抛错', () async {
    Dnd5eRules.resetForTests();
    expect(() => Dnd5eRules.profile, throwsStateError);
    await Dnd5eRules.configure(loadBuiltinProfileForTest());
    expect(() => Dnd5eRules.configure(loadBuiltinProfileForTest()), throwsStateError);
    Dnd5eRules.resetForTests(); // 不影响其它测试文件（每个文件独立进程）
  });
}
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_store_test.dart`
预期：FAIL，`Not found: '.../rule_profile_store.dart'`

- [ ] **步骤 3：实现 `rule_profile_store.dart`**

```dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/rule_profile.dart';
import '../domain/rule_profile_resolver.dart';

class RuleProfileStore {
  static const assetPath = 'assets/rules/dnd5e-2024.rules.json';

  /// 读内置档案并解析。`readAsset` 可注入（测试用它读仓库文件，避免 rootBundle）。
  static Future<RuleProfile> loadBuiltin({
    Future<Map<String, Object?>> Function(String path)? readAsset,
  }) async {
    final reader = readAsset ?? _readRootBundle;
    final raw = await reader(assetPath);
    final result = RuleProfileResolver.resolveBuiltin(raw);
    if (result.profile == null) {
      throw StateError(
        '内置规则档案非法（$assetPath）：\n${result.errors.join('\n')}',
      );
    }
    return result.profile!;
  }

  static Future<Map<String, Object?>> _readRootBundle(String path) async {
    final text = await rootBundle.loadString(path);
    return Map<String, Object?>.from(jsonDecode(text) as Map);
  }
}
```

- [ ] **步骤 4：改 `main.dart`**

```dart
import 'package:flutter/material.dart';

import 'src/app/dnd_table_app.dart';
import 'src/features/characters/domain/dnd5e_rules.dart';
import 'src/features/rules/data/rule_profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Dnd5eRules.configure(await RuleProfileStore.loadBuiltin());
  runApp(const OhMyDungeonApp());
}
```

- [ ] **步骤 5：在 `Dnd5eRules` 加装配入口（本步骤只加，不改表查询）**

文件顶部补 `import 'package:flutter/foundation.dart' show visibleForTesting;` 与
`import '../../rules/domain/rule_profile.dart';`，然后加：

```dart
  static RuleProfile? _profile;

  static RuleProfile get profile {
    final profile = _profile;
    if (profile == null) {
      throw StateError(
        'Dnd5eRules 尚未配置规则档案：请在启动时 await Dnd5eRules.configure(...)',
      );
    }
    return profile;
  }

  static Future<void> configure(RuleProfile profile) async {
    if (_profile != null) {
      throw StateError('规则档案已配置，重复 configure 被拒绝');
    }
    _profile = profile;
  }

  @visibleForTesting
  static void resetForTests() => _profile = null;
```

- [ ] **步骤 6：运行测试与全量回归**

运行：`cd apps/client_flutter && flutter test test/rules/rule_profile_store_test.dart`
预期：PASS
运行：`cd apps/client_flutter && flutter test`
预期：**仍然全绿**（本任务不改变任何行为；现有测试不调用 `Dnd5eRules.profile`）

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/rules/data/rule_profile_store.dart \
        apps/client_flutter/lib/main.dart \
        apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart \
        apps/client_flutter/test/rules/rule_profile_store_test.dart \
        apps/client_flutter/test/rules/rule_profile_test_support.dart
git commit -m "feat(rules): 内置档案启动装配与 Dnd5eRules.configure"
```

---

## 任务 6：`Dnd5eRules` 表查询改读档案（删除职业表与中文匹配）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart`
- 修改：`apps/client_flutter/test/dnd5e_rules_verification_test.dart`（改为对档案断言）
- 修改：`apps/client_flutter/test/dnd5e_rules_test.dart`（补 `setUpAll` 装配）

- [ ] **步骤 1：加全局测试装配（先失败）**

一旦 `Dnd5eRules` 的表查询改读 `profile`，**所有**间接调用它的测试（quick_build、character_pages…）
都会抛 `StateError`。用 Flutter 的全局测试入口一次性装配，避免每个文件写 `setUpAll`：

```dart
// test/flutter_test_config.dart —— flutter test 会自动加载本文件
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dnd_table_client/src/features/characters/domain/dnd5e_rules.dart';
import 'package:dnd_table_client/src/features/rules/domain/rule_profile_resolver.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final raw = jsonDecode(
    File('assets/rules/dnd5e-2024.rules.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final result = RuleProfileResolver.resolveBuiltin(raw);
  if (result.profile == null) {
    throw StateError('内置档案非法（测试装配失败）：\n${result.errors.join('\n')}');
  }
  await Dnd5eRules.configure(result.profile!);
  await testMain();
}
```

运行：`cd apps/client_flutter && flutter test test/dnd5e_rules_test.dart`
预期：PASS（装配生效）

- [ ] **步骤 2：改写表查询 API（签名从"职业名字符串"改为"条目身份"）**

删除 `_hitDice`、`_classSavingThrows`、`_fullCasterSlots`、`_preparedDivine/Sorcerer/Wizard/HalfCaster/Warlock`、
`_secondWindUses`、`_rageUses`、`_casterProgression`、`_preparedSpellTable`、`usesThirdCasterProgression`
以及所有 `classSummary.contains(...)`。新 API：

```dart
  /// 由一个职业条目解析出的规则形态。`classSummary` 只用于展示，不参与规则判断。
  static ResolvedClassRules resolveClassRules({
    required String? entryId,
    required String classSummary,
    Map<String, Object?> structured = const <String, Object?>{},
    List<RuleDiagnostic>? diagnostics,
  }) {
    final slug = _slugFor(entryId: entryId, classSummary: classSummary);
    final entryRules = structured['classRules'] is Map
        ? ClassRuleSet.parse(
            Map<String, Object?>.from(structured['classRules']! as Map),
            path: r'$.structured.classRules',
            diagnostics: diagnostics ?? <RuleDiagnostic>[],
          )
        : null;
    return RuleProfileResolver.resolveClassRules(
      profile: profile, slug: slug, entryRules: entryRules);
  }

  /// slug：条目 id 的最后一段，或展示名经档案 aliases 精确匹配。
  static String _slugFor({required String? entryId, required String classSummary}) {
    if (entryId != null && entryId.contains('/')) {
      return entryId.split('/').last.trim().toLowerCase();
    }
    final normalized = classSummary.trim().toLowerCase();
    if (profile.classRules(normalized) != null) return normalized;
    return normalized; // 未知则查不到，按"未声明"处理
  }
```

保留并改为委托的 API（**其余调用方无需改动**）：

```dart
  static int abilityModifier(int score) => ruleAbilityModifier(score);
  static int proficiencyBonus(int level) => ruleProficiencyBonus(level);
  static String formatModifier(int modifier) => formatRuleModifier(modifier);

  static int averageHitPoints({
    required String className,
    required int level,
    required Map<String, Object?> abilities,
  }) {
    final constitution = abilityScore(abilities, 'con');
    final die = resolveClassRules(entryId: null, classSummary: className).hitDie;
    if (die == null) {
      // 未声明生命骰：不猜，只按体质调整值计，且总生命至少 1。
      return (abilityModifier(constitution) * level.clamp(1, 20)).clamp(1, 1 << 30);
    }
    return averageHitPointsForHitDie(
      hitDie: die, level: level, constitution: constitution);
  }

  static int? hitDieFor({String? entryId, required String classSummary}) =>
      resolveClassRules(entryId: entryId, classSummary: classSummary).hitDie;

  static Set<String> classSavingThrows(String classSummary) =>
      resolveClassRules(entryId: null, classSummary: classSummary).savingThrowAbilities;
```

**步骤 3c：保留旧公开签名作为过渡 shim（本任务**不得**破坏构建）**

任务 8 才迁移调用方。因此本任务**必须**让 `quick_build.dart` / `character.dart` /
`character_detail_page.dart` / `character_editor_page.dart` 等既有调用点**继续编译且行为不变**：
旧方法全部保留原签名，内部改为"按 `classSummary` 当 slug 解析 → 查 profile → 委托新 API"。

```dart
  // ── 过渡 shim：签名不变，内部改为读档案（任务 8 迁移调用方后删除） ──
  static Map<String, int> spellSlotMaximums({
    required String classSummary,
    required int level,
  }) => resolveClassRules(entryId: null, classSummary: classSummary).spellSlots(level);

  static List<Dnd5eClassResource> classResources({
    required String classSummary,
    required int level,
    Map<String, Object?> abilities = const <String, Object?>{},
  }) => resolveClassRules(entryId: null, classSummary: classSummary)
      .resourcesAt(level, {
        for (final key in Dnd5eRules.abilityLabels.keys)
          key: abilityScore(abilities, key),
      })
      .map((r) => Dnd5eClassResource(
            id: r.id, name: r.name, maximum: r.maximum, recovery: r.recovery))
      .toList(growable: false);

  static bool usesPactMagic(String classSummary) =>
      resolveClassRules(entryId: null, classSummary: classSummary).spellcastingMode == 'pact';

  /// 契约魔法位：由档案的 `pact` 原型提供（不再有硬编码表）。
  static Map<String, int> pactSlotMaximums(int level) {
    final pact = profile.progression('pact');
    if (pact == null) return const {};
    if (level < pact.minimumLevel) return const {};
    return pact.slots?.at(level) ?? const {};
  }

  static int? preparedSpellMaximums({
    required String classSummary,
    required int level,
  }) => resolveClassRules(entryId: null, classSummary: classSummary).preparedLimit(level);
```

`abilityLabels` / `skills` / `defaultAbilities` 三个常量保留（被大量调用点与 UI 使用）；
`abilityLabels` 的内容改为从 `profile.abilities` 派生**仅用于校验**，展示用的中文标签保留在代码里
（标签是 UI 文案，不是规则数值）。

**新增 API（任务 8 会用它迁移）：** `resolveClassRules(...)`、`hitDieFor(...)`,
以及 `spellSlotMaximumsFromRules` / `classResourcesFromRules`（签名见上文 §4.2）。

- [ ] **步骤 3：把 `dnd5e_rules_verification_test.dart` 改为对档案断言**

保留全部期望值，只把数据来源换成档案解析结果：

```dart
  group('职业生命骰（2024 官方核心表）', () {
    test('12 职业生命骰与豁免对照 SRD 5.2', () {
      const expected = {
        'barbarian': [12, ['str','con']], 'bard': [8, ['dex','cha']],
        'cleric': [8, ['wis','cha']],     'druid': [8, ['int','wis']],
        'fighter': [10, ['str','con']],   'monk': [8, ['dex','wis']],
        'paladin': [10, ['wis','cha']],   'ranger': [10, ['dex','str']],
        'rogue': [8, ['dex','int']],      'sorcerer': [6, ['con','cha']],
        'warlock': [8, ['wis','cha']],    'wizard': [6, ['int','wis']],
      };
      expected.forEach((slug, value) {
        final rules = Dnd5eRules.profile.classRules(slug)!;
        expect(rules.hitDie, value[0], reason: slug);
        expect(rules.savingThrowAbilities, value[1], reason: slug);
      });
    });
  });
```

法术位用例改为经 `resolveClassRules(...).spellSlots(level)` 断言（期望值一个字都不改）。

- [ ] **步骤 4：运行规则测试**

运行：`cd apps/client_flutter && flutter test test/dnd5e_rules_test.dart test/dnd5e_rules_verification_test.dart`
预期：PASS

- [ ] **步骤 5：验证"代码里再无职业名表"**

运行：`cd apps/client_flutter && grep -rn "contains('战士')\|contains('法师')\|_fullCasterSlots\|_preparedDivine" lib/ || echo CLEAN`
预期：`CLEAN`

- [ ] **步骤 6：跑全量回归（本任务的最大风险点）**

运行：`cd apps/client_flutter && flutter test`
预期：**全绿**，通过数不减（本任务不新增测试，只改内部实现；`dnd5e_rules_verification_test.dart` 的
期望值一个字都不许改，除非是把它从"直接断言硬编码表"改成"断言档案解析结果"）。
若出现失败，**优先怀疑 shim 的 slug 解析**（例如 `classSummary` 是"战士（奥法骑士）"这类散文时解析不到
slug —— 此时 shim 必须回退到"按档案的 name/aliases 精确匹配"而不是子串匹配）。

- [ ] **步骤 7：Commit**

```bash
git add apps/client_flutter/lib/src/features/characters/domain/dnd5e_rules.dart \
        apps/client_flutter/lib/src/features/characters/data/character_markdown_codec.dart \
        apps/client_flutter/test/dnd5e_rules_test.dart \
        apps/client_flutter/test/dnd5e_rules_verification_test.dart
git commit -m "refactor(rules): Dnd5eRules 表查询改读内置档案，删除职业名匹配与硬编码表"
```

---

## 任务 6.5：任务 6 审查后的收尾（**在任务 7 之前完成**）

任务 6 已通过两阶段审查（行为等价性对拍：12 职业 × 5 级的法术位/准备上限/生命骰/豁免/契约位/资源逐项一致）。
以下是审查给出的应修项：

1. **收紧"反向包含"匹配（重要）**：`dnd5e_rules.dart` 的 slug 解析现在放行裸子串，
   于是 `星界游侠` 会命中 `游侠`（正是 §9 反对的"子串猜测"）。按契约 §3.6（已更新）改为
   **精确相等**或**`<别名><分隔符>` 前缀**（分隔符限 `（` `(` 空格 `-` `/`）。加测试：
   - `战士（奥法骑士）` → `fighter`（前缀命中）、`法师 / Wizard` → `wizard`；
   - `星界游侠` → **不命中**（`hitDie == null`，不是 ranger 的 10）。
2. **`abilityLabels` 与 `profile.abilities` 的一致性守卫（重要）**：`dnd5e_rules.dart` 的注释承诺
   "两者的键集合由测试断言一致"，但全仓无人断言。在档案测试（`builtin_rule_profile_test.dart`）里补一条
   `expect(Dnd5eRules.abilityLabels.keys.toSet(), profile.abilities)`（或与档案 `abilities` 数组比对）。
3. **修断链注释（次要）**：`dnd5e_rules.dart` 里引用的 `§10.1` 不存在，改为 `§10 第 1 条`。
4. **`classResources` 的 `abilities` 传参（重要，落地在任务 8）**：三处既有调用点
   （`character.dart:157`、`quick_build.dart:92`、`character_editor_page.dart:3012`）都没传 `abilities`，
   导致公式类资源（诗人激励 = 魅力调整值）按调整值 0 算。任务 8 迁移时必须把 `abilities` 传进去，
   并在**任务 8 的验收**里显式检查一次真实数值（例如 CHA 16 的诗人激励应为 3）。

## 任务 7：`structured_class_rules.dart` 只认新契约（保留旧签名不破坏构建）

**为什么不能直接删**：`StructuredClassRules.skillChoice` 被 `character_editor_page.dart:1537`（创建向导的技能步骤）
使用，`startingEquipmentChoice` 被 `rules_driven_character_builder.dart:176` 与
`character_editor_page.dart:1706` 使用。**直接删 = 构建红 + 向导功能倒退**。
因此本任务的原则与任务 6 相同：**内部改为只读新契约，旧签名全部保留为过渡 shim**（任务 8 迁移调用方后删除）。

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/domain/structured_class_rules.dart`
- 修改：`apps/client_flutter/test/structured_class_rules_test.dart`
- 修改：`apps/client_flutter/test/tooling/private_content_package_validation_test.dart`（它调用了 `skillChoice`）

- [ ] **步骤 1：明确每个方法的去留**

| 方法 | 处理 |
|---|---|
| `savingThrowAbilities` | 改为委托 `Dnd5eRules.resolveClassRules(...)`（只读 `structured.classRules`）；删掉中文散文 `savingThrows` 解析 |
| `hitDie`（新增） | 委托 `resolveClassRules(...).hitDie` |
| `skillChoice` | **不再解析散文**：改为从条目 `rules.choices` 里找 `optionType == "skill"` 的选择，取其 `minimum` 作 count、内联 `options` 的标签（或字符串元素）作 options；找不到就返回 `StructuredSkillChoice.empty` |
| `startingEquipmentChoice` | 保持原样（读 `structured.startingEquipmentChoice.maximum`）——它是旧形状，等 S2 的装备选择落地后再迁移 |
| `preparedSpellLimit` | 保留签名，内部直接 `resolveClassRules(...).preparedLimit(level)`；**删除** `preparedSpellcasting` 开关与"属性调整值 + 等级"公式（新契约里没有这两个概念） |
| 私有 `_validSkills` / 两个中文正则 / 散文解析 | 全部删除 |

- [ ] **步骤 2：重写测试（旧断言锚定的是已废弃语义）**

`structured_class_rules_test.dart` 里 10+ 条 `preparedSpellLimit` 断言与 3 条散文技能断言都要重写：

```dart
  test('savingThrowAbilities 与 hitDie 直接读 classRules', () {
    const entry = ContentEntry(
      id: 'test:class/astral', type: 'class', slug: 'astral', name: '星界骑士',
      body: [], revision: 1,
      structured: {
        'classRules': {'hitDie': 10, 'savingThrowAbilities': ['wis', 'cha']},
      },
    );
    expect(StructuredClassRules.savingThrowAbilities(entry), {'wis', 'cha'});
    expect(StructuredClassRules.hitDie(entry), 10);
    expect(StructuredClassRules.preparedSpellLimit(
      entry, abilities: const {}, level: 5), isNull, reason: '未声明 prepared 表');
  });

  test('中文散文 savingThrows / skills 不再被解析', () {
    const entry = ContentEntry(
      id: 'test:class/legacy', type: 'class', slug: 'legacy', name: '旧写法',
      body: [], revision: 1,
      structured: {'savingThrows': '力量与体质', 'skills': '选择2项：运动、察觉'},
    );
    expect(StructuredClassRules.savingThrowAbilities(entry), isEmpty);
    expect(StructuredClassRules.skillChoice(entry).count, 0);
    expect(StructuredClassRules.skillChoice(entry).options, isEmpty);
  });

  test('skillChoice 改为读 rules.choices 里的 optionType: "skill"', () {
    final entry = ContentEntry(
      id: 'test:class/astral', type: 'class', slug: 'astral', name: '星界骑士',
      body: [], revision: 1,
      structured: const {'classRules': {'hitDie': 10}},
      rules: CharacterRuleDefinition.fromJson({
        'progression': [
          {'levels': [1], 'choices': [
            {'id': 'class-skills', 'label': '选择两项技能熟练', 'optionType': 'skill',
             'minimum': 2, 'maximum': 2,
             'options': ['洞悉', '医药', '说服']},
          ]},
        ],
      }),
    );
    expect(StructuredClassRules.skillChoice(entry).count, 2);
    expect(StructuredClassRules.skillChoice(entry).options, ['洞悉', '医药', '说服']);
  });

  test('preparedSpellLimit 只读职业自身的 prepared 表', () {
    const entry = ContentEntry(
      id: 'test:class/astral', type: 'class', slug: 'astral', name: '星界骑士',
      body: [], revision: 1,
      structured: {
        'classRules': {
          'hitDie': 10,
          'spellcasting': {'mode': 'prepared', 'ability': 'cha', 'prepared': [3, 4, 5]},
        },
      },
    );
    expect(StructuredClassRules.preparedSpellLimit(
      entry, abilities: const {'cha': 20}, level: 1), 3);
    expect(StructuredClassRules.preparedSpellLimit(
      entry, abilities: const {'cha': 20}, level: 9), 5, reason: '短数组向上沿用');
  });
```

- [ ] **步骤 3：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/structured_class_rules_test.dart`
预期：FAIL（散文仍被解析、`hitDie` 方法不存在）

- [ ] **步骤 4：实现**

`structured_class_rules.dart` 改为薄适配器，全部经 `Dnd5eRules.resolveClassRules({entryId, classSummary, structured})`
取值（**不要**在本文件里重复解析 `classRules`，那是解析器的职责）。
`skillChoice` 读 `entry.rules` 的 `choices`（含 `progression[].choices`），按 `optionType == 'skill'` 取第一个匹配。

- [ ] **步骤 5：跑该文件 + 全量回归**

运行：`cd apps/client_flutter && flutter test test/structured_class_rules_test.dart`
预期：PASS
运行：`cd apps/client_flutter && flutter test`
预期：全绿。`private_content_package_validation_test.dart` 若因 `skillChoice` 语义变化失败，
按其新语义更新断言（它读的是私有包，缺少私有包时本应跳过）。

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib/src/features/characters/domain/structured_class_rules.dart \
        apps/client_flutter/test/structured_class_rules_test.dart \
        apps/client_flutter/test/tooling/private_content_package_validation_test.dart
git commit -m "refactor(rules): StructuredClassRules 只读 classRules 与 rules.choices，删除散文解析"
```

## 任务 8：切换全部消费方（构建器 / 快速创建 / 角色卡 / 项目器 / 编辑器）

> **已知过渡期倒退（任务 10 后消失）**：本任务把消费方切到新契约后，在私有包内容
> 尚未迁移到新契约（任务 10）之前，会出现以下**已知且可接受**的临时倒退：
> - **编辑器技能步骤**：真实职业条目还没有 `optionType: "skill"` 的选择时
>   `StructuredClassRules.skillChoice(...).count == 0`，背景技能不再被排除，
>   退化为"18 技能全列表"。
> - **规则选择卡片**：半提取态下会显示"资料库中缺少 skill 选项"。
> - **私有包校验测试**：`test/tooling/private_content_package_validation_test.dart`
>   的技能选择用例已被显式 `skip`（契约迁移前不放宽断言），任务 10 完成后**必须**
>   移除该 `skip` 并确认转绿。

**文件：**
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/quick_build.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/character_rule_projector.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/spell_selection_policy.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`

- [ ] **步骤 1：写失败测试（新契约端到端）**

```dart
// test/rules/homebrew_class_end_to_end_test.dart
test('自制职业：只靠 classRules 就能算出 HP/豁免/技能/法术位/资源', () {
  final rules = Dnd5eRules.resolveClassRules(
    entryId: 'my-pack:class/astral-knight',
    classSummary: '星界骑士',
    structured: {
      'classRules': {
        'hitDie': 10,
        'savingThrowAbilities': ['wis', 'cha'],
        'spellcasting': {
          'mode': 'prepared', 'ability': 'cha', 'archetype': 'half-caster',
          'slots': {'5': {'1': 4, '2': 2}},
        },
        'resources': [
          {'id': 'surge', 'name': '星界涌动', 'recovery': 'shortRestOne',
           'maximum': {'formula': 'level'}},
        ],
      },
    },
  );

  expect(rules.hitDie, 10);
  expect(rules.savingThrowAbilities, {'wis', 'cha'});
  expect(rules.spellSlots(1), {'1': 2});
  expect(rules.spellSlots(5), {'1': 4, '2': 2});
  expect(rules.preparedLimit(5), 7);
  expect(rules.spellcastingAbility, 'cha');
  final resources = rules.resourcesAt(7, const {'cha': 16});
  expect(resources.single.id, 'surge');
  expect(resources.single.maximum, 7);
  expect(resources.single.recovery, 'shortRestOne');
});

test('未知职业不猜：数值为空而非回退到相近职业', () {
  final rules = Dnd5eRules.resolveClassRules(
    entryId: 'my-pack:class/unknown', classSummary: '星界游侠');
  expect(rules.hitDie, isNull);
  expect(rules.spellSlots(5), isEmpty);
  expect(rules.preparedLimit(5), isNull);
  expect(rules.savingThrowAbilities, isEmpty);
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/homebrew_class_end_to_end_test.dart`
预期：FAIL（`ResolvedClassRules.resourcesAt` 等未实现/未接线）

- [ ] **步骤 3：改构建器**

`rules_driven_character_builder.dart`：
- 取 `classEntry = _selectedEntry(build, 'class')` 后调用
  `Dnd5eRules.resolveClassRules(entryId: classEntry?.id, classSummary: classEntry?.name ?? '', structured: classEntry?.structured ?? const {})`。
- `saves` 初值来自 `rules.savingThrowAbilities`（删除对 `StructuredClassRules.savingThrowAbilities` 的调用）。
- `_averageHitPoints` 改为接收 `int? hitDie`；`hitDie == null`（职业未声明）时按 §3.6 第 3 步
  只计体质调整值（最低 1），实现为：

```dart
  int _averageHitPoints({
    required int? hitDie,
    required int level,
    required int constitution,
  }) {
    final safeLevel = level.clamp(1, 20);
    if (hitDie == null) {
      // 未声明生命骰：不猜，只按体质调整值计，且总生命至少 1。
      return (ruleAbilityModifier(constitution) * safeLevel).clamp(1, 1 << 30);
    }
    return Dnd5eRules.averageHitPointsForHitDie(
      hitDie: hitDie, level: safeLevel, constitution: constitution);
  }
```

- 产出的 `data` 增加：
```dart
        'classIdentity': {
          'entryId': classEntry?.id,
          'slug': classEntry?.slug,
          'name': classEntry?.name,
          // §3.12：部分声明是一等功能，声明范围要随角色持久化，供所有界面共用
          'declaredLevels': {
            'min': _declaredMinLevel(classEntry),
            'max': _declaredMaxLevel(classEntry, rules),
          },
        },
        'hitDie': rules.hitDie,
        'savingThrowAbilities': rules.savingThrowAbilities.toList(),
```
- `spellSlots` 一律由 `rules.spellSlots(build.level)` 生成（不再读 `spellSlot:` grant）；
  `classResources` 由 `rules.resourcesAt(build.level, abilities)` 生成。

- [ ] **步骤 4：改 `character.dart` / `quick_build.dart` / `projector` / 详情页 / 编辑器**

- `character.dart`：`classResources` getter 改为

```dart
  List<Dnd5eClassResource> get classResources {
    final explicit = _explicitClassResources();
    if (explicit.isNotEmpty) return explicit;
    final identity = dataMap['classIdentity'];
    final slug = identity is Map ? '${identity['slug'] ?? ''}' : '';
    if (slug.isEmpty) return const [];
    final rules = Dnd5eRules.resolveClassRules(
      entryId: identity is Map ? identity['entryId'] as String? : null,
      classSummary: classSummary,
    );
    return rules.resourcesAt(level, {
      for (final entry in abilityMap.entries)
        entry.key: _intValue(entry.value) == 0 ? 10 : _intValue(entry.value),
    }).map((r) => Dnd5eClassResource(
          id: r.id, name: r.name, maximum: r.maximum, recovery: r.recovery)).toList(growable: false);
  }
```

- `quick_build.dart`：删除 `_saves` / `_abilities` 的"职业名分支"改为读档案
  `Dnd5eRules.profile.classRules(slug)`；`classEntryId` 存在时用条目规则，否则用档案；
  写 `classIdentity`。
- `character_rule_projector.dart`：为没有 `classIdentity` 的角色按
  `profile.classRules(name.toLowerCase())` 或 `profile.classRules(slug)` 精确匹配回填；
  匹配不到则写 `{'entryId': null, 'slug': null, 'name': classSummary}` 并保留空资源。
- `character_detail_page.dart` 的 `_slotMaximums()`：兜底改为
  `Dnd5eRules.resolveClassRules(...).spellSlots(character.level)`。
- `character_editor_page.dart`：等级摘要与法术选择改用 `resolveClassRules(...)`。
- **武器攻击（删除 `Dnd5eRules._weaponProfiles` 与 `weaponProfile`）**：改为读物品条目自身的声明。
  `character_detail_page.dart` 的 `_deriveWeaponAttacks` 改为：

```dart
List<_WeaponAttackAction> _deriveWeaponAttacks(CharacterSheet character) {
  final attacks = <_WeaponAttackAction>[];
  for (final item in _normalizeInventory(character.inventoryList)) {
    final entryId = item['entryId'];
    final entry = entryId == null
        ? null
        : widget.contentEntries.where((c) => c.id == entryId).firstOrNull;
    final damage = '${entry?.structured['damage'] ?? ''}'.trim();   // 例："1d8 挥砍"
    final match = RegExp(r'^(\d*d\d+(?:[+-]\d+)?)\s*(\S+)?$').firstMatch(damage);
    if (match == null) continue;            // 未声明伤害 → 不产出攻击（不猜）
    final die = match.group(1)!;
    final damageType = (match.group(2) ?? '').trim();
    final finesse = entry?.structured['finesse'] == true ||
        '${entry?.structured['category'] ?? ''}'.contains('灵巧');
    final ability = finesse
        ? (Dnd5eRules.abilityBonus(character.abilityMap, 'dex') >=
                   Dnd5eRules.abilityBonus(character.abilityMap, 'str')
               ? 'dex'
               : 'str')
        : (Dnd5eRules.weaponAbility(entry?.structured) ?? 'str');
    final attackBonus = Dnd5eRules.attackBonus(
      abilities: character.abilityMap, level: character.level, ability: ability);
    attacks.add(_WeaponAttackAction(
      name: '${entry?.name ?? item['name']}',
      bonus: attackBonus,
      toHit: '${Dnd5eRules.formatModifier(attackBonus)} 命中',
      damage: '$die ${damageType.isEmpty ? '' : damageType}'.trim(),
      damageFormula: Dnd5eRules.damageFormula(
        Dnd5eWeaponProfile(name: '${entry?.name}', ability: ability,
            damageDie: die, damageType: damageType),
        character.abilityMap),
      damageType: damageType,
    ));
  }
  return attacks;
}
```

`Dnd5eRules.weaponAbility(structured)` 只读声明，不再按名字猜：
- `structured.ability` ∈ {str,dex} → 用它；
- 否则 `structured.category` 含"远程" → dex；
- 否则 str。
`_weaponProfiles` / `weaponProfile()` **整体删除**（连同 `dnd5e_rules_test.dart` 里对 `weaponProfile('长弓')` 的用例，改为构造带 `damage` 的物品条目断言）。

- [ ] **步骤 5：运行回归**

运行：`cd apps/client_flutter && flutter test`
预期：全绿；若 `character_pages_test.dart` / `character_builder_choices_test.dart` 里出现旧
`spellSlot:`/散文夹具，按新契约改写夹具（不是改断言）。

额外验收（本步骤必查）：
- **三处 `classResources` 调用点都传 `abilities`**（`character.dart` 的 getter、`quick_build.dart`、
  `character_editor_page.dart`），并写一条断言：CHA 16 的吟游诗人「诗人激励」上限 == 3（不是 1）；
- **删除全部过渡 shim**（`dnd5e_rules.dart` 里标了"任务 8 迁移后删除"的 8 个方法）与裸子串匹配；
- `grep -rn "contains('法师')\|contains('战士')" apps/client_flutter/lib` 在 UI 预设之外应无命中
  （`quick_build.dart` 的 `_classAbilityPresets` 若仍需按名预设，改为**读档案 `classAliases`** 的键，
  不再写死中文名）。

- [ ] **步骤 6：Commit**

```bash
git add -A apps/client_flutter
git commit -m "refactor(rules): 全部消费方切换到规则档案与 classRules"
```

---

## 任务 8.5：任务 8 遗留的两处消费方（**在任务 9 之前完成**）

任务 8 已把主要消费方切到新契约，但有两处**未迁移**，且都会在任务 10 迁移内容后暴露为功能故障：

1. **`spell_selection_policy.dart` 仍读旧的顶层 `structured.spellcasting.progression`**。
   任务 10 把私有包改成只声明 `classRules.spellcasting` 之后，编辑器的"法术"步骤会得到 `unconfigured`
   （法术列表为空）。改为经 `Dnd5eRules.resolveClassRules(entryId, ...)` 读取
   `spellcasting` 的 `mode`/`ability`/`listTags`/`prepared`/`cantrips`/`maxSpellLevel` 与原型表；
   找不到声明时保持"未配置"（不猜）。加测试：只声明 `classRules.spellcasting` 的条目应能给出
   正确的可学环阶与数量上限。

2. **武器"远程/灵巧"判据对真实物品数据不成立**。PHB 物品的 `properties` 是文本（如 `"灵巧，轻型"`），
   `category` 里也不含"远程"，因此长弓当前会按力量算伤害。两步修：
   - 现在：`weaponAbility` 除 `structured.ability` 外，还要识别 `properties` 含 `灵巧`（→ 取 STR/DEX 较优）
     与含 `弹药`/`远程`（→ DEX）；
   - 任务 10：提取器为武器物品**显式输出 `structured.ability`**（由规则书的属性列推导），
     让判据不再依赖文本匹配。任务 10 的验收里加一条：长弓的派生攻击必须用敏捷。

## 任务 8.6：任务 8 审查观察（收尾时清）

> **执行后记**：本任务与任务 9 分成了两个 commit，但 `38c11d5`（8.6）单独 checkout 时分析会报错
> （编辑器仍在读 `progression.level`，那是任务 9 才改的）。分支 tip 是绿的；若日后需要逐 commit 可编译，
> 把这两个 commit 压成一个即可。
> 另：编辑器"无内容时的职业兜底清单"从写死的 4 项变为档案 `classAliases` 的全部 12 项（排序后默认首个是吟游诗人），
> 因此有一处测试期望随之变化（默认职业的 HP 由战士 d10 变吟游诗人 d8）。属有意的行为变化，已记录。

1. **`spellSlotMaximumsFromRules` 成了死代码**（`dnd5e_rules.dart`）：全仓无调用点（任务 8 把 shim 删了之后
   没人再用它）。要么删掉，要么让详情页/编辑器真正用它；**不要留无调用的薄包装**。
2. **`character_editor_page.dart` 的 `_defaultClassOptions = ['战士','法师','游荡者','牧师']`** 仍写死 4 个中文职业名
   （纯 UI 兜底：资料库没有 class 条目时的快速选择项）。按"职业名只存在于档案数据"的原则，
   改为从档案 `classAliases` 的键派生（会给出 12 项，比 4 项更完整）；若担心 UI 变长，就保留但加注释说明
   它是"无内容时的 UI 兜底"而非规则数据。

## 任务 9：规则定义收紧（grant kind 9 项 + progression 用 `levels`）

**文件：**
- 修改：`apps/client_flutter/lib/src/features/rules/domain/character_rule_definition.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/domain/rules_driven_character_builder.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart:2617-2622`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_character_rules_view.dart:142-147`
- 测试：`apps/client_flutter/test/rules/grant_kind_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
test('progression 只接受 levels 数组，旧的 level 字段被拒绝', () {
  final step = RuleProgressionDefinition.fromJson({
    'levels': [4, 8, 12, 16],
    'grants': [{'id': 'asi-int', 'kind': 'ability', 'label': '智力 +1',
                'target': 'int', 'value': 1}],
  });
  expect(step.levels, [4, 8, 12, 16]);

  expect(() => RuleProgressionDefinition.fromJson({'level': 4}), throwsFormatException);
  expect(() => RuleProgressionDefinition.fromJson({'levels': [0]}), throwsFormatException);
  expect(() => RuleProgressionDefinition.fromJson({'levels': [21]}), throwsFormatException);
  expect(() => RuleProgressionDefinition.fromJson({'levels': []}), throwsFormatException);
  expect(() => RuleProgressionDefinition.fromJson({'levels': [4, 4]}), throwsFormatException);
});

test('grant kind 收敛为 9 项，resource/conditionResistance/note 被拒绝', () {
  expect(RuleGrantKind.values.map((k) => k.name).toSet(), {
    'feature', 'proficiency', 'spell', 'equipment', 'action',
    'speed', 'armorClass', 'hitPoints', 'ability',
  });
  for (final gone in ['resource', 'conditionResistance', 'note']) {
    expect(() => RuleGrantKind.parse(gone), throwsFormatException, reason: gone);
  }
});

test('hitPoints 与 ability grant 参与派生', () {
  // 构造 rules.progression[1].grants = [
  //   {kind: 'hitPoints', value: 2}, {kind: 'ability', target: 'cha', value: 1} ]
  // 断言 maxHp 比无 grant 时多 2，且 cha 派生 +1（法术 DC +1）
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/grant_kind_test.dart`
预期：FAIL

- [ ] **步骤 3：实现**

- `RuleProgressionDefinition` 把 `final int level` 换成 `final List<int> levels`：
  必填非空、元素 1..20、去重后排序；出现旧的 `level` 键直接抛
  `FormatException('Rule progression requires "levels": [..]，不再接受 "level"')`。
  引擎（`CharacterRulesEngine`）与编辑器里所有 `step.level` 改为 `step.levels.contains(...)`
  / 按每个等级展开。
- `RuleGrantKind` 删除三项；`parse` 的 `orElse` 抛 `FormatException('Unknown rule grant kind: $value')` 保持。
- 构建器：把 `ledger.grantsOfKind(RuleGrantKind.hitPoints)` 的 `value`/`formula`
  累加进 `maxHp`（`formula` 经 `MaxSpec.tryParse` 求值，`level` 用职业等级）；
  把 `ability` grant 收集成 `Map<String,int>`，在算 HP/AC/豁免/技能/DC **之前**叠加到 abilities。
- 两个图标 map 删除被移除的三项。

- [ ] **步骤 4：运行确认通过并全量回归**

运行：`cd apps/client_flutter && flutter test`
预期：全绿；测试夹具里若有 `kind: 'resource'` 一并改为 `classRules.resources`

- [ ] **步骤 5：Commit**

```bash
git add -A apps/client_flutter
git commit -m "feat(rules): grant kind 收敛为 9 项，实现 hitPoints/ability，移除三项空转"
```

---

## 任务 10：提取器重写与重提取金标

**文件：**
- 修改：`scripts/extract_phb_2024_v2.py`（`parse_class_core_table`、`parse_spell_selection_table`、`_build_spell_slot_progression`、`extract_class`）
- 修改：`scripts/test_phb_2024_v2_tools.py`
- 创建：`apps/client_flutter/test/rules/reextracted_bundle_golden_test.dart`

- [ ] **步骤 1：改 `parse_class_core_table`（散文 → 结构化）**

```python
ABILITY_KEYS = {"力量": "str", "敏捷": "dex", "体质": "con",
                "智力": "int", "感知": "wis", "魅力": "cha"}

def parse_saving_throws(value: str) -> list[str]:
    """'力量与体质' → ['str','con']；顺序按 PHB 表的书写顺序。"""
    return [ABILITY_KEYS[cn] for cn in ABILITY_KEYS if cn in value]

def parse_skill_choice(value: str) -> dict[str, Any] | None:
    """'选择2项：驯兽、运动、威吓' → {'count':2,'options':[...]}
       '任选3项（见第一章）'      → {'count':3,'options':'any'}"""
    m = re.search(r"(\d+)\s*项", value)
    if not m:
        return None
    count = int(m.group(1))
    after = value.split("：", 1)[-1] if "：" in value else ""
    options = [s.strip() for s in re.split(r"[、,，]", after) if s.strip()]
    if not options or "见" in after:
        return {"count": count, "options": "any"}
    return {"count": count, "options": options}
```

在 `parse_class_core_table` 里把 `savingThrows` / `skills` 转换为
`classRules.savingThrowAbilities` / `classRules.hitDie`（int），技能与法术**选择**改由
`rules.progression[].choices` 输出，
`structured` 变成：

```python
structured["classRules"] = {
    "hitDie": int(die),
    "savingThrowAbilities": saving_throws,
    # 技能选择不再写进 classRules，而是作为一条 optionType: "skill" 的 choice 放进 progression

    # spellcasting 由 extract_class 补，见步骤 2
}
```

保留 `primaryAbility` / `weaponProficiency` / `armorProficiency` / `startingEquipment` 作为**展示元数据**
（不属于 `classRules`）。

- [ ] **步骤 2：`parse_spell_selection_table` 输出表而不是四列行数组**

```python
            return {
                "mode": "prepared" if "准备法术" in header[maximum_column] else "known",
                "ability": ability,
                "listTags": [f"spell-list:{class_slug}"],
                "archetype": ARCHETYPE_BY_CLASS[class_slug],      # 见步骤 3
                "prepared": {str(row["level"]): row["maximumLeveledSpells"] for row in progression},
                "cantrips": {str(row["level"]): row["maximumCantrips"] for row in progression},
                "maximumSpellLevel": {str(row["level"]): row["maximumSpellLevel"] for row in progression},
            }
```

- [ ] **步骤 3：删除 `_build_spell_slot_progression` 与脚本内的法术位表**

```python
ARCHETYPE_BY_CLASS = {
    "吟游诗人": "full-caster", "牧师": "full-caster", "德鲁伊": "full-caster",
    "术士": "full-caster", "法师": "full-caster",
    "圣武士": "half-caster", "游侠": "half-caster",
    "魔契师": "pact",
}
```

删除 `full_caster_slots` / `half_caster_slots` / `pact_magic_slots` 三个脚本内副本与整个
`_build_spell_slot_progression`；调用点一并删除。**法术位数值从此只存在于客户端内置档案**。

- [ ] **步骤 3b：另外两份私有包的版本号（必须先做，否则它们会被新校验拒绝）**

`formatVersion: 3` 是唯一被接受的版本，所以**三份**现有私有包都要重生成：

| 脚本 | 改动 | 产物 |
|---|---|---|
| `scripts/extract_phb_2024_v2.py:1617` | 版本号 + 步骤 1–3 的契约改造 | `private-imports/phb-2024-v2-bundle.json` |
| `scripts/extract_monster_manual_private.py:742` | **只改版本号**（怪物条目不含 `rules`/`classRules`） | `private-imports/mm-2024-v1-bundle.json` |
| `scripts/extract_dmg_2024_items.py:172` | **只改版本号** | `private-imports/dmg-2024-items-v1-bundle.json` |

同时更新 `scripts/validate_phb_2024_v2.py:63` 的版本白名单为 `(3,)`，
以及 `scripts/build_private_core_bundle.py:50`、`scripts/test_release_packaging.py:22,57` 里的 2 → 3。

- [ ] **步骤 4：改脚本测试**

在 `scripts/test_phb_2024_v2_tools.py` 增加：

```python
    def test_class_entries_use_structured_rules(self):
        """职业条目只允许新契约形状，不得残留散文与逐级 grant。"""
        bundle = build_bundle()  # 复用现有夹具构建函数
        for entry in bundle["entries"]:
            if entry["type"] != "class":
                continue
            structured = entry["structured"]
            self.assertNotIn("savingThrows", structured)
            self.assertNotIn("skills", structured)
            self.assertNotIn("preparedSpellcasting", structured)
            self.assertIsInstance(structured["classRules"]["hitDie"], int)
            text = json.dumps(entry.get("rules") or {}, ensure_ascii=False)
            self.assertNotIn("spellSlot:", text)
            self.assertNotIn("classResource:", text)
```

- [ ] **步骤 5：运行脚本测试**

运行：`cd /mnt/c/Users/26047/Desktop/dnd-table-tool && python3 -m unittest scripts.test_phb_2024_v2_tools -v`
预期：PASS

- [ ] **步骤 6：重提取并写金标测试**

运行：`python3 scripts/extract_phb_2024_v2.py`（按脚本现有用法生成 bundle 到 `private-imports/`）
然后：

```dart
// test/rules/reextracted_bundle_golden_test.dart
void main() {
  final file = File('../../private-imports/phb-2024-v2-bundle.json');
  if (!file.existsSync()) {
    // 与现有私有路径测试一致：缺私有包时跳过
    return;
  }
  test('重提取产物：12 职业 × 4 级派生数值与改造前一致', () {
    final bundle = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final classes = (bundle['entries']! as List)
        .whereType<Map>()
        .where((e) => e['type'] == 'class')
        .toList();
    expect(classes, hasLength(12));
    for (final entry in classes) {
      final rules = Dnd5eRules.resolveClassRules(
        entryId: entry['id'] as String,
        classSummary: entry['name'] as String,
        structured: Map<String, Object?>.from(entry['structured']! as Map),
      );
      for (final level in [1, 5, 11, 20]) {
        // 期望值来自官方表（与 dnd5e_rules_verification_test.dart 同源）
        expect(rules.spellSlots(level), expectedSlots(entry['slug'] as String, level),
            reason: '${entry['slug']} L$level');
      }
      expect(rules.hitDie, isNotNull, reason: entry['slug'] as String);
    }
  });
}
```

- [ ] **步骤 6b：内容侧补两件事**

1. 为武器物品显式输出 `structured.ability`（`str`/`dex`），使 `weaponAbility` 不再依赖
   `properties` 文本匹配；
2. 移除 `private_content_package_validation_test.dart` 里那条 `skip`
   （`'私有包内容尚未迁移到新契约（任务 10 迁移后移除此 skip）'`），确认转绿。

- [ ] **步骤 7：全量门禁**

运行：`cd /mnt/c/Users/26047/Desktop/dnd-table-tool && npm run test:scripts && cd apps/client_flutter && dart analyze lib test && flutter test`
预期：脚本测试全绿、analyze 0 问题、客户端测试全绿且数量 **≥ 923**

- [ ] **步骤 8：Commit**

```bash
git add scripts/extract_phb_2024_v2.py scripts/test_phb_2024_v2_tools.py \
        apps/client_flutter/test/rules/reextracted_bundle_golden_test.dart
git commit -m "feat(content): 提取器输出新契约形状，删除脚本内重复的法术位表"
```

---

## 任务 10.5：职业规则展示层改读 `classRules`（**执行任务 10 时发现的缺口**）

**为什么必须做**：任务 10 让提取器不再写顶层 `structured.hitDie`（字符串，旧）/
`structured.savingThrows`（散文）/ `structured.skills`（散文）——它们是 `classRules.hitDie` /
`classRules.savingThrowAbilities` / `rules.choices` 的**旧形状副本**，留着就是"一个概念两种形状"。
但展示层仍在读那三个旧键，内容迁移后会**静默丢行**：

- `character_editor_page.dart` 的 `_StructuredRuleSummary`（`fields: ['primaryAbility','hitDie']`
  与 `fields: ['savingThrows','skills','weaponProficiency','armorProficiency']`）；
- `content_type_registry.dart` 的 `_ClassDefinition.searchableFields` / `buildMetadata`（资料库卡片）；
- `content_library_controller.dart` + `content_repository.dart` 的**生命骰 facet**
  （facet 计数与筛选共用 `normalizedContentFacetValues` 这个唯一 choke point）。

**口径**：规则值一律经 `Dnd5eRules.resolveClassRules` / `StructuredClassRules`（条目 ∪ 档案），
展示元数据（`primaryAbility` / `weaponProficiency` / `armorProficiency` / `startingEquipment`）
继续读 `structured`。**未声明即不显示该行**，不显示 `0`、不猜、不回退散文。

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/domain/class_rule_summary.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_type_registry.dart`
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_schema_registry.dart`
- 测试：`apps/client_flutter/test/class_rule_summary_display_test.dart`

**步骤：**

1. 新增 `ClassRuleSummary.of(ContentEntry?)` → `({String? hitDie, String? savingThrows, String? skillChoice})`：
   `hitDie` → `d${resolved.hitDie}`；`savingThrows` → `resolved.savingThrowAbilities` 经
   `Dnd5eRules.abilityLabels` 映射后按 `、` 连接；`skillChoice` → `StructuredClassRules.skillChoice`
   的 `选择N项：…` / `任选N项（任意技能）`。三者在"未声明/空"时返回 null。
2. `_StructuredRuleSummary` 不再接收裸 `fields`，改为接收算好的 `(label, icon, value)` 条目；
   两个调用点合成"展示元数据（`structured`）+ 规则值（`ClassRuleSummary`）"两个来源。
3. `_ClassDefinition.buildMetadata` 渲染 主属性 / 生命骰 / 豁免熟练 / 技能选择；
4. 生命骰 facet：在 `ContentSchemaRegistry.normalizeFacetValues` 里，`type == 'class'` 且
   `field == 'hitDie'` 且 `value == null` 时从 `classRules.hitDie` 派生（**唯一**派生点，facet 计数
   与筛选共用）；值用 `d<N>` 字符串与旧数据保持一致。
5. 按新契约改写测试夹具（`_fighterRulesContent` 等）：删掉顶层 `hitDie`/`savingThrows`/`skills`，
   改成 `classRules: {hitDie: 10, savingThrowAbilities: ['str','con'], spellcasting: …}`；
   **断言不变**（`find.text('d10')` / `find.text('力量与体质')` 必须仍然通过）。
6. 新增测试：只有 `classRules`、没有旧键的职业条目在编辑器摘要卡与资料库卡片上都显示
   生命骰 d10 / 豁免熟练 力量与体质 / 技能选择 选择2项…；facet 计数与筛选生效；
   **完全未声明时该行不出现**。

---

## 任务 11：导入器接入规则诊断

**文件：**
- 修改：`apps/client_flutter/lib/src/features/content/domain/content_import_report.dart`
- 修改：`apps/client_flutter/lib/src/features/content/data/import/content_package_importer.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/content_import_preview_dialog.dart`
- 测试：`apps/client_flutter/test/rules/import_rule_diagnostics_test.dart`

- [ ] **步骤 1：写失败测试**

```dart
test('非法 classRules 阻断整包，路径精确到字段', () async {
  final report = await importer.previewJson(jsonEncode({
    'formatVersion': 2, 'id': 'bad-pack', 'name': 'bad', 'version': '1',
    'locale': 'zh-CN', 'system': 'dnd5e-2024', 'entryCount': 1,
    'entries': [
      {'id': 'bad-pack:class/x', 'type': 'class', 'slug': 'x', 'name': 'X',
       'revision': 1, 'body': [],
       'structured': {'classRules': {'hitDex': 10}}},
    ],
  }));
  expect(report.valid, isFalse);
  expect(report.errors.single.path, contains('structured.classRules.hitDex'));
  expect(report.errors.single.message, contains('hitDie'));
});

test('缺 hitDie 只给 warning，不阻断', () async {
  final report = await importer.previewJson(jsonEncode({ /* 同上，去掉 hitDie */ }));
  expect(report.valid, isTrue);
  expect(report.warnings.single.code, 'missingCoreField');
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/rules/import_rule_diagnostics_test.dart`
预期：FAIL（`warnings` 不存在 / 未校验 classRules）

- [ ] **步骤 3：`ContentImportReport` 新增 `warnings`**

```dart
  final List<ContentValidationError> errors;
  final List<ContentValidationError> warnings;   // 新增（默认 const []）
```

`_buildReport` 增加可选具名参数 `List<ContentValidationError> warnings = const []`。

- [ ] **步骤 4：格式版本与内置 slug 保护**

```dart
  // 只接受一个格式版本
  if (formatVersionValue != 3) {
    errors.add(const ContentValidationError(
      path: r'$.formatVersion',
      message: '只支持 formatVersion 3；这是旧格式，请用新版工具重新生成/重提取',
    ));
  }
```

```dart
  // class 条目：slug 命中内置职业时必须显式声明 classRules（杜绝静默继承）
  if (normalizedType == 'class') {
    final slug = '${normalizedJson['slug'] ?? ''}'.trim().toLowerCase();
    final hasClassRules = rawClassRules is Map;
    if (!hasClassRules && Dnd5eRules.profile.classRules(slug) != null) {
      errors.add(ContentValidationError(
        path: r'$.entries[' + '$i' + r'].structured.classRules',
        message: 'slug "$slug" 属于内置职业：若要覆盖其数值必须显式声明 classRules，'
                 '否则会静默继承内置数值（builtinSlugRequiresExplicitRules）',
      ));
    }
  }
```

在 `import_rule_diagnostics_test.dart` 追加两条：`formatVersion: 2` 被拒；
`slug: "fighter"` 且无 `classRules` 的 class 条目被拒。

- [ ] **步骤 5：导入器调用解析器**

在 `previewJson` 的 entry 解析循环里，对 `type == 'class'` 的条目：

```dart
          final diagnostics = <RuleDiagnostic>[];
          final rawClassRules = (normalizedJson['structured'] as Map?)?['classRules'];
          if (rawClassRules is Map) {
            ClassRuleSet.parse(
              Map<String, Object?>.from(rawClassRules),
              path: r'$.entries[' + '$i' + r'].structured.classRules',
              diagnostics: diagnostics,
            );
          } else if (normalizedType == 'class') {
            diagnostics.add(RuleDiagnostic(
              path: r'$.entries[' + '$i' + r'].structured.classRules',
              severity: RuleSeverity.warning,
              code: 'unresolvedClassRule',
              message: '职业条目未声明 classRules，将只使用内置档案（若有同 slug）',
            ));
          }
          for (final diagnostic in diagnostics) {
            final target = diagnostic.severity == RuleSeverity.error ? errors : warnings;
            target.add(ContentValidationError(
                path: diagnostic.path, message: '${diagnostic.message}（${diagnostic.code}）'));
          }
```

`previewJson` 与 `previewDndPack` 把 `warnings` 一并传给 `_buildReport`。

- [ ] **步骤 6：导入预览展示 warnings**

在 `ContentImportPreviewDialog` 的 errors 区块之后加入同样的列表，用
`Theme.of(context).colorScheme.tertiary` 与 `Icons.info_outline`，文案前缀"提示（不阻断导入）"。

- [ ] **步骤 7：运行测试与全量门禁**

运行：`cd apps/client_flutter && flutter test test/rules/import_rule_diagnostics_test.dart && flutter test`
预期：PASS 且全绿

- [ ] **步骤 8：Commit**

```bash
git add apps/client_flutter/lib/src/features/content apps/client_flutter/test/rules/import_rule_diagnostics_test.dart
git commit -m "feat(content): 导入器接入规则诊断，error 阻断、warning 提示"
```

---

## 任务 12：把"声明范围"体现到所有界面（§3.12）

**文件：**
- 创建：`apps/client_flutter/lib/src/features/characters/presentation/widgets/declared_level_banner.dart`
- 修改：`apps/client_flutter/lib/src/features/content/presentation/widgets/content_character_rules_view.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_editor_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_upgrade_page.dart`
- 修改：`apps/client_flutter/lib/src/features/characters/presentation/character_detail_page.dart`
- 测试：`apps/client_flutter/test/declared_levels_ui_test.dart`

- [ ] **步骤 1：写共用读取器 + 失败测试**

```dart
// lib/src/features/characters/domain/declared_levels.dart
class DeclaredLevels {
  const DeclaredLevels({required this.min, this.max});
  final int min;
  final int? max; // null = 该职业完全没有等级声明

  bool covers(int level) => max != null && level >= min && level <= max!;
  bool get isEmpty => max == null;

  static DeclaredLevels fromCharacter(CharacterSheet character) {
    final identity = character.dataMap['classIdentity'];
    final raw = identity is Map ? identity['declaredLevels'] : null;
    if (raw is! Map) return const DeclaredLevels(min: 1);
    return DeclaredLevels(
      min: raw['min'] is num ? (raw['min']! as num).toInt() : 1,
      max: raw['max'] is num ? (raw['max']! as num).toInt() : null,
    );
  }
}
```

```dart
// test/declared_levels_ui_test.dart
testWidgets('等级滑杆标出未声明区间，并在超出时给信息条', (tester) async {
  await tester.pumpWidget(MaterialApp(home: CharacterEditorPage(
    // 夹具：职业只声明到 5 级
    initialDeclaredLevels: const DeclaredLevels(min: 1, max: 5),
  )));
  expect(find.textContaining('职业声明：1–5 级'), findsOneWidget);

  // 把等级拉到 8 级
  await tester.drag(find.byType(Slider), const Offset(300, 0));
  await tester.pumpAndSettle();
  expect(find.textContaining('该职业未声明 6 级以上内容'), findsOneWidget);
  expect(find.textContaining('仍可继续'), findsOneWidget);
});

testWidgets('角色卡在未声明等级显示"未声明"而不是 0', (tester) async {
  await tester.pumpWidget(MaterialApp(home: CharacterDetailPage(
    character: _characterAtLevel8WithPartialClass,
  )));
  await tester.tap(find.text('法术'));
  await tester.pumpAndSettle();
  expect(find.textContaining('该职业未声明该等级的内容'), findsOneWidget);
  expect(find.textContaining('准备上限 0'), findsNothing);
});
```

- [ ] **步骤 2：运行确认失败**

运行：`cd apps/client_flutter && flutter test test/declared_levels_ui_test.dart`
预期：FAIL（`DeclaredLevels` 不存在 / 找不到文案）

- [ ] **步骤 3：做共用信息条组件**

```dart
// widgets/declared_level_banner.dart
class DeclaredLevelBanner extends StatelessWidget {
  const DeclaredLevelBanner({required this.levels, required this.currentLevel, super.key});

  final DeclaredLevels levels;
  final int currentLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = levels.isEmpty
        ? '该职业未声明任何等级内容'
        : '职业声明：${levels.min}–${levels.max} 级';
    final beyond = !levels.isEmpty && !levels.covers(currentLevel);
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(beyond ? Icons.info_outline : Icons.rule_outlined,
              color: beyond ? theme.colorScheme.tertiary : theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: theme.textTheme.bodyMedium),
              if (beyond) ...[
                const SizedBox(height: 4),
                Text('该职业未声明 $currentLevel 级以上内容，你仍可继续（数值按未声明处理）',
                    style: theme.textTheme.bodySmall),
              ],
            ],
          )),
        ]),
      ),
    );
  }
}
```

- [ ] **步骤 4：接到 5 个界面（每处 3–6 行）**

| 界面 | 改动 |
|---|---|
| `content_character_rules_view.dart` | 规则视图顶部插入 `DeclaredLevelBanner`（用条目自身声明的范围；`currentLevel` 传 `levels.min` 以免出现"超出"文案） |
| `character_editor_page.dart` | ① 等级滑杆的 `Slider` 外包一层，用 `activeColor`/`inactiveColor` 区分已声明区间，并在未声明区间显示刻度（`SliderTheme` + `divisions` 不变，仅改颜色与 `semanticFormatterCallback` 文案）；② 步骤面板顶部渲染 `DeclaredLevelBanner(levels: widget.declaredLevels, currentLevel: _level)` |
| `character_upgrade_page.dart` | `CharacterUpgradePlan` 增加 `beyondDeclaredLevel`（由 planner 依据 `DeclaredLevels` 计算），页面在"确认升级"按钮上方渲染同一条信息条 |
| `character_detail_page.dart` | 法术位/职业资源面板：当 `!levels.covers(character.level)` 且对应数值为空时，显示"该职业未声明该等级的内容"；**不得**把未声明渲染成 0 |
| `character_import_preview_dialog.dart` | 预览行的副标题追加"职业声明：1–N 级"（信息样式，非错误色） |

- [ ] **步骤 5：跑测试与全量回归**

运行：`cd apps/client_flutter && flutter test test/declared_levels_ui_test.dart && flutter test`
预期：PASS 且全绿

- [ ] **步骤 6：Commit**

```bash
git add apps/client_flutter/lib apps/client_flutter/test/declared_levels_ui_test.dart
git commit -m "feat(ui): 职业声明范围（部分声明）在全部相关界面可见"
```

---

## 收尾检查（P2 完成标志）

- [ ] `grep -rn "contains('战士')\|_fullCasterSlots\|_preparedDivine\|_hitDice = " apps/client_flutter/lib/` → 无输出
- [ ] `cd apps/client_flutter && flutter test` → 全绿，数量 ≥ 923
- [ ] `cd apps/client_flutter && dart analyze lib test` → 0 问题
- [ ] `npm run test:scripts` → 27+ 通过
- [ ] `npm run lint:server` → 0 问题（未改服务端，作为回归）
- [ ] 用私有包做一次手工冒烟：建一个 5 级吟游诗人 → 法术位 4/3/2、准备上限 9、HP 与改造前一致

---

## 收尾说明：老角色的属性 base 不回填（W6 结论，只记录不实现）

W3 之前派生的角色卡里，`abilities` 是**旧语义的最终值**（多等级 `ability` 授予只算 1 次）。
新语义按每个已达等级各生效一次，因此 `baseAbilitiesFrom` 从这些最终值反推出的 base 会**偏低**；
但派生出的最终值**稳定不变**（`base − N×bonus` 再加回 `N×bonus` 仍是原值），
所以用户看到的数值不会漂移，只是 base 与"新语义下重新建号"的角色不同。
当前是 `0.1.0` 预发布、内置档案不含 `ability` grant（只有示例包用到），
一次性迁移的收益不足以抵消改存档的风险，故**不做迁移**；等选择系统（计划 2）落定后如仍需
统一 base 口径，再单独评估。

---

## 后续计划（本计划之外）

| 计划 | 内容 |
|---|---|
| 计划 2 | P5 选择系统（§3.10 全部：值选项 + 内联 grants + 自动授予、显式 `optionType: "spell"` 法术选择 + `countsToward`、`repeatable`、`requires`、`group`/`help`、装备 A/B、`progression[].levels` 数组，以及编辑器选择面板改造） |
| 计划 3 | P6 文档（§9.1 重写、§7.7 行为变化清单、§2/§16 基线、README 教程、AGENTS.md、§13.6 合规项） |

> 规格里的 P3（校验）与 P4（grant kind 收紧）已并入本计划（任务 9 与任务 11），
> 因此本计划完成后只剩选择系统与文档两块。
