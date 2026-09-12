// character_editor_page.dart 的 part：详情步骤、职业摘要与规则授予预览。
part of 'character_editor_page.dart';

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.name,
    required this.avatarBytes,
    required this.isPickingAvatar,
    required this.avatarPickError,
    required this.onPickAvatar,
    required this.appearanceController,
    required this.personalityController,
    required this.idealsController,
    required this.bondsController,
    required this.flawsController,
    required this.backstoryController,
    required this.privateNotesController,
  });

  final String name;
  final Uint8List? avatarBytes;
  final bool isPickingAvatar;
  final String? avatarPickError;
  final VoidCallback onPickAvatar;
  final TextEditingController appearanceController;
  final TextEditingController personalityController;
  final TextEditingController idealsController;
  final TextEditingController bondsController;
  final TextEditingController flawsController;
  final TextEditingController backstoryController;
  final TextEditingController privateNotesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AvatarPicker(
          key: const Key('standard-character-avatar-picker'),
          previewBytes: avatarBytes,
          isUploading: isPickingAvatar,
          error: avatarPickError,
          onPick: onPickAvatar,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(name.trim().isEmpty ? '角色名尚未填写' : name.trim()),
          subtitle: const Text('除角色名外，其余故事信息均可稍后补充。'),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('character-story-appearance'),
          controller: appearanceController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: '外貌',
            hintText: '体态、服饰、显著特征',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('character-story-personality'),
          controller: personalityController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '性格特点'),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const Key('character-story-ideals'),
                controller: idealsController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '理念'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: const Key('character-story-bonds'),
                controller: bondsController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '牵绊'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('character-story-flaws'),
          controller: flawsController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '缺点'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('character-story-backstory'),
          controller: backstoryController,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(labelText: '背景故事'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('character-story-private-notes'),
          controller: privateNotesController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: '私密笔记',
            helperText: '仅保存在角色卡中，不作为公开人物简介。',
          ),
        ),
      ],
    );
  }
}

/// 职业摘要卡的条目：展示元数据（`primaryAbility` / `weaponProficiency` /
/// `armorProficiency` / `startingEquipment`）继续读 `structured`；规则值
/// （`hitDie` / `savingThrows` / `skills`）一律经 [ClassRuleSummary] 这唯一口径。
///
/// 规则值未声明（`null`）时不产生该行——不回退旧散文键、不显示 `0`。
/// "key → 规则值"的成员映射只有一处实现（[ClassRuleSummary.fieldValues]）：
/// 这里不重列记录成员名。
List<({String field, String value})> _classSummaryItems(
  ContentEntry? entry,
  List<String> fields,
) {
  final classFields = ClassRuleSummary.fieldValues(
    ClassRuleSummary.of(entry),
    fields: fields,
  );
  final items = <({String field, String value})>[];
  for (final field in fields) {
    final value = classFields.containsKey(field)
        ? classFields[field]
        : _structuredFieldText(entry?.structured[field]);
    if (value != null && value.isNotEmpty) {
      items.add((field: field, value: value));
    }
  }
  return items;
}

/// 展示元数据（`structured`）的纯文本化：可迭代值按顿号连接，空值为 `null`。
String? _structuredFieldText(Object? value) {
  if (value == null) return null;
  final text = value is Iterable
      ? value.map((item) => '$item').join('、')
      : '$value'.trim();
  return text.isEmpty ? null : text;
}

class _StructuredRuleSummary extends StatelessWidget {
  const _StructuredRuleSummary({required this.title, required this.items});

  final String title;
  final List<({String field, String value})> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card.filled(
        key: Key('structured-rule-summary-$title'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rule_folder_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_iconFor(item.field)),
                  title: Text(_labelFor(item.field)),
                  subtitle: Text(item.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelFor(String field) => switch (field) {
    'primaryAbility' => '主属性',
    'hitDie' => '生命骰',
    'savingThrows' => '豁免熟练',
    'skills' => '技能选择',
    'weaponProficiency' => '武器熟练',
    'armorProficiency' => '护甲熟练',
    'startingEquipment' => '初始装备',
    _ => field,
  };

  static IconData _iconFor(String field) => switch (field) {
    'primaryAbility' => Icons.hexagon_outlined,
    'hitDie' => Icons.favorite_outline,
    'savingThrows' => Icons.health_and_safety_outlined,
    'skills' => Icons.psychology_outlined,
    'weaponProficiency' => Icons.gavel_outlined,
    'armorProficiency' => Icons.shield_outlined,
    'startingEquipment' => Icons.inventory_2_outlined,
    _ => Icons.info_outline,
  };
}

/// 「自动获得」预览的一行：授予定义 + 来源条目 + 生效等级
/// （`null` = 条目级 `rules.grants`，与等级无关）。
typedef RuleGrantPreviewRow = ({
  ContentEntry entry,
  RuleGrantDefinition grant,
  int? sourceLevel,
});

/// 「自动获得」预览的行集合（纯函数，可独立测试）。
///
/// 与引擎 [CharacterRulesEngine.evaluate] **同源**：多等级步骤（`levels`）按
/// **每个已达等级**各展开一次（§3.5"同一批效果在多个等级重复生效"），不是只取
/// `reached.last`。引擎按 `ruleUnitKey(entry, id, level)` 产出 N 个生效单元，
/// 这里也必须产 N 行，否则预览与运行期数值不同源。
///
/// 两类重复在"每行一次"的展示里必须去掉，否则同一件东西会重复列出：
/// 1. 同一生效单元被两个条目重复覆盖（迁移期允许步骤重叠）→ 按生效单元键去重；
/// 2. `kind: action` 逐级展开会产生 N 条**内容完全相同**的动作行（动作身份是
///    `entryId + grant.id`，没有随等级变化的语义），运行期 `data['actions']`
///    也只认一条 → 按动作身份只保留最早生效的那条。
List<RuleGrantPreviewRow> ruleGrantPreviewRows(
  List<ContentEntry> entries,
  int level,
) {
  final rows = <RuleGrantPreviewRow>[];
  final seen = <String>{};
  for (final entry in entries) {
    final rules = entry.rules;
    if (rules == null) continue;

    void add(RuleGrantDefinition grant, int? sourceLevel) {
      final identity = grant.kind == RuleGrantKind.action
          ? ruleActionKey(entry.id, grant.id)
          : ruleUnitKey(entry.id, grant.id, sourceLevel);
      if (!seen.add(identity)) return;
      rows.add((entry: entry, grant: grant, sourceLevel: sourceLevel));
    }

    for (final grant in rules.grants) {
      add(grant, null);
    }
    for (final progression in rules.progression) {
      for (final stepLevel in progression.levels) {
        if (stepLevel > level) continue;
        for (final grant in progression.grants) {
          add(grant, stepLevel);
        }
      }
    }
  }
  return rows;
}

class _RuleGrantPreview extends StatelessWidget {
  const _RuleGrantPreview({required this.entries, required this.level});

  final List<ContentEntry> entries;
  final int level;

  @override
  Widget build(BuildContext context) {
    final grants = ruleGrantPreviewRows(entries, level);
    if (grants.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: 8),
                  Text('自动获得', style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 8),
              for (final item in grants)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_grantIcon(item.grant.kind)),
                  title: Text(item.grant.label),
                  subtitle: Text(
                    item.sourceLevel == null
                        ? item.entry.name
                        : '${item.entry.name} · 等级 ${item.sourceLevel}',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _grantIcon(RuleGrantKind kind) {
    return switch (kind) {
      RuleGrantKind.feature => Icons.auto_awesome_outlined,
      RuleGrantKind.proficiency => Icons.workspace_premium_outlined,
      RuleGrantKind.spell => Icons.auto_fix_high_outlined,
      RuleGrantKind.equipment => Icons.inventory_2_outlined,
      RuleGrantKind.action => Icons.bolt_outlined,
      RuleGrantKind.speed => Icons.directions_run_outlined,
      RuleGrantKind.armorClass => Icons.shield_outlined,
      RuleGrantKind.hitPoints => Icons.favorite_outline,
      RuleGrantKind.ability => Icons.hexagon_outlined,
    };
  }
}
