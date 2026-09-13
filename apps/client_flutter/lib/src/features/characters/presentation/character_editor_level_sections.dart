// character_editor_page.dart 的 part：等级进度、声明等级控件与属性/技能区。
part of 'character_editor_page.dart';

class _LevelProgressionSection extends StatelessWidget {
  const _LevelProgressionSection({
    required this.level,
    required this.className,
    required this.classEntry,
    required this.classRules,
    required this.abilities,
    required this.onChanged,
  });

  final int level;
  final String className;
  final ContentEntry? classEntry;

  /// **已解析**的职业规则，由调用方（向导页唯一的 `_resolveClassRules`）传入。
  ///
  /// **必填**：本组件不得自行解析——那会与同屏的头部 HP 预览 / 法术配额口径分叉（M）。
  final ResolvedClassRules classRules;
  final Map<String, int> abilities;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // §3.12：声明范围只有一种口径，与 Builder 写入值同源（[DeclaredLevels.fromEntry]）；
    // 滑杆据此区分已声明 / 未声明区间。
    final declaredLevels = DeclaredLevels.fromEntry(classEntry);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeclaredLevelBanner(
            levels: declaredLevels,
            currentLevel: level,
          ),
          const SizedBox(height: 8),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LevelSectionHeader(level: level),
                  const SizedBox(height: 8),
                  _DeclaredLevelSlider(
                    level: level,
                    declaredLevels: declaredLevels,
                    onChanged: onChanged,
                  ),
                  const SizedBox(height: 4),
                  _DeclaredRangeCaption(
                    levels: declaredLevels,
                    level: level,
                  ),
                  const SizedBox(height: 8),
                  _LevelSummaryChips(
                    rules: classRules,
                    level: level,
                    abilities: abilities,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 等级卡片标题行：左"等级"、右"当前等级 N"。
class _LevelSectionHeader extends StatelessWidget {
  const _LevelSectionHeader({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('等级', style: Theme.of(context).textTheme.titleMedium),
        ),
        InputChip(
          avatar: const Icon(Icons.trending_up_outlined),
          label: Text('当前等级 $level'),
        ),
      ],
    );
  }
}

/// 等级滑杆 + 两侧加减按钮。
///
/// §3.12：轨道按"已声明 / 未声明"**双色**（已声明 = 主题色，未声明 =
/// `outlineVariant`，唯一实现见 [DeclaredLevelTrackShape]），并把刻度提示画出来。
/// 滑块本身保持主题色：它是"当前等级"的抓手，不是区间标记——区间由轨道和下方
/// 文案表达，滑到未声明等级时另有 [DeclaredLevelBanner] 信息条。
class _DeclaredLevelSlider extends StatelessWidget {
  const _DeclaredLevelSlider({
    required this.level,
    required this.declaredLevels,
    required this.onChanged,
  });

  final int level;
  final DeclaredLevels declaredLevels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final declaredColor = theme.colorScheme.primary;
    return Row(
      children: [
        IconButton.filledTonal(
          key: const Key('standard-level-decrement-button'),
          tooltip: '降低等级',
          onPressed: level <= 1 ? null : () => onChanged(level - 1),
          icon: const Icon(Icons.remove),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: declaredColor,
              inactiveTrackColor: theme.colorScheme.outlineVariant,
              thumbColor: declaredColor,
              trackShape: DeclaredLevelTrackShape(
                levels: declaredLevels,
                min: 1,
                max: kMaxCharacterLevel.toDouble(),
              ),
            ),
            child: Slider(
              value: level.toDouble(),
              min: 1,
              max: kMaxCharacterLevel.toDouble(),
              divisions: kMaxCharacterLevel - 1,
              label: '$level',
              semanticFormatterCallback: (value) =>
                  declaredLevels.covers(value.round())
                  ? '第 ${value.round()} 级（已声明）'
                  : '第 ${value.round()} 级（该职业未声明）',
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
        ),
        IconButton.filledTonal(
          key: const Key('standard-level-increment-button'),
          tooltip: '提高等级',
          onPressed: level >= kMaxCharacterLevel
              ? null
              : () => onChanged(level + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// 滑杆下方的区间说明；文案口径只有一处（[DeclaredLevels.declaredRangeCaption]）。
class _DeclaredRangeCaption extends StatelessWidget {
  const _DeclaredRangeCaption({required this.levels, required this.level});

  final DeclaredLevels levels;

  /// 当前等级：只为着色（当前等级不在声明范围内时用信息色）。
  final int level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final covered = levels.covers(level);
    return Text(
      levels.declaredRangeCaption,
      key: const Key('standard-level-declared-range'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: covered
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.tertiary,
      ),
    );
  }
}

/// HP / 熟练加值 / 法术位 / 职业资源摘要。数值口径全部来自同一个 `classRules`
/// （条目声明 ∪ 内置档案），并带 `abilities` 以便 `formula: ability:<key>` 结算。
class _LevelSummaryChips extends StatelessWidget {
  const _LevelSummaryChips({
    required this.rules,
    required this.level,
    required this.abilities,
  });

  final ResolvedClassRules rules;
  final int level;
  final Map<String, int> abilities;

  @override
  Widget build(BuildContext context) {
    final hitDie = rules.hitDie;
    final hp = hitDie == null
        ? (Dnd5eRules.abilityModifier(
                    Dnd5eRules.abilityScore(abilities, 'con'),
                  ) *
                  level.clamp(1, 20))
              .clamp(1, 1 << 30)
        : Dnd5eRules.averageHitPointsForHitDie(
            hitDie: hitDie,
            level: level,
            constitution: Dnd5eRules.abilityScore(abilities, 'con'),
          );
    final spellSlots = rules.spellSlots(level);
    final classResources = Dnd5eRules.classResourcesFromRules(
      rules: rules,
      level: level,
      abilities: abilities,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(label: Text('HP $hp')),
        Chip(label: Text('熟练 +${Dnd5eRules.proficiencyBonus(level)}')),
        if (spellSlots.isNotEmpty)
          Chip(label: Text('法术位 ${_formatSpellSlots(spellSlots)}')),
        if (classResources.isNotEmpty)
          Chip(
            label: Text('职业资源 ${_formatClassResources(classResources)}'),
          ),
      ],
    );
  }

  static String _formatSpellSlots(Map<String, int> slots) {
    final entries = slots.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));
    return entries
        .map(
          (entry) => '${Dnd5eRules.spellLevelLabel(entry.key)} ${entry.value}',
        )
        .join(' / ');
  }

  static String _formatClassResources(List<Dnd5eClassResource> resources) {
    return resources.map((item) => '${item.name} ${item.maximum}').join(' / ');
  }
}

class _AbilityScoreSection extends StatelessWidget {
  const _AbilityScoreSection({
    required this.method,
    required this.scores,
    required this.controllers,
    required this.onMethodChanged,
    required this.onApplyRecommended,
    required this.onRoll,
    required this.onChanged,
  });

  final AbilityScoreMethod method;
  final Map<String, int> scores;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<AbilityScoreMethod> onMethodChanged;
  final VoidCallback onApplyRecommended;
  final VoidCallback onRoll;
  final void Function(String ability, int value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isComplete = Dnd5eRules.abilityLabels.keys.every((ability) {
      final score = scores[ability];
      return score != null && score >= 3 && score <= 20;
    });
    final remaining = AbilityScoreGenerator.pointBuyRemaining(scores);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('属性', style: theme.textTheme.titleMedium)),
              InputChip(
                avatar: Icon(
                  isComplete ? Icons.check_circle_outline : Icons.error_outline,
                ),
                label: Text(isComplete ? '属性已完成' : '属性需调整'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<AbilityScoreMethod>(
            segments: const [
              ButtonSegment(
                value: AbilityScoreMethod.standardArray,
                icon: Icon(Icons.view_array_outlined),
                label: Text('标准数组', key: Key('ability-method-standard')),
              ),
              ButtonSegment(
                value: AbilityScoreMethod.pointBuy,
                icon: Icon(Icons.calculate_outlined),
                label: Text('27 点购点', key: Key('ability-method-point-buy')),
              ),
              ButtonSegment(
                value: AbilityScoreMethod.rolled,
                icon: Icon(Icons.casino_outlined),
                label: Text('随机', key: Key('ability-method-rolled')),
              ),
            ],
            selected: {method},
            showSelectedIcon: false,
            onSelectionChanged: (selection) =>
                onMethodChanged(selection.single),
          ),
          const SizedBox(height: 12),
          if (method == AbilityScoreMethod.pointBuy)
            Row(
              children: [
                Icon(
                  remaining < 0 ? Icons.error_outline : Icons.toll_outlined,
                  color: remaining < 0 ? theme.colorScheme.error : null,
                ),
                const SizedBox(width: 8),
                Text(
                  '剩余 $remaining / ${AbilityScoreGenerator.pointBuyBudget} 点',
                  key: const Key('point-buy-remaining'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: remaining < 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                key: Key(
                  method == AbilityScoreMethod.rolled
                      ? 'reroll-ability-scores'
                      : 'apply-recommended-ability-array',
                ),
                onPressed: method == AbilityScoreMethod.rolled
                    ? onRoll
                    : onApplyRecommended,
                icon: Icon(
                  method == AbilityScoreMethod.rolled
                      ? Icons.casino_outlined
                      : Icons.auto_fix_high_outlined,
                ),
                label: Text(
                  method == AbilityScoreMethod.rolled ? '重新掷骰' : '按职业推荐分配',
                ),
              ),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return GridView.count(
                crossAxisCount: compact ? 2 : 3,
                childAspectRatio: compact ? 1.7 : 2.2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final entry in Dnd5eRules.abilityLabels.entries)
                    method == AbilityScoreMethod.pointBuy
                        ? _PointBuyAbilityTile(
                            ability: entry.key,
                            label: entry.value,
                            scores: scores,
                            onChanged: (value) {
                              controllers[entry.key]?.text = '$value';
                              onChanged(entry.key, value);
                            },
                          )
                        : TextField(
                            key: Key('standard-ability-${entry.key}-field'),
                            controller: controllers[entry.key],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: entry.value,
                              helperText:
                                  '调整值 ${Dnd5eRules.formatModifier(Dnd5eRules.abilityModifier(scores[entry.key] ?? 10))}',
                            ),
                            onChanged: (value) =>
                                onChanged(entry.key, int.tryParse(value) ?? 0),
                          ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PointBuyAbilityTile extends StatelessWidget {
  const _PointBuyAbilityTile({
    required this.ability,
    required this.label,
    required this.scores,
    required this.onChanged,
  });

  final String ability;
  final String label;
  final Map<String, int> scores;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final score = scores[ability] ?? 8;
    final canIncrease = AbilityScoreGenerator.canSetPointBuyScore(
      scores,
      ability,
      score + 1,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    '$score  ${Dnd5eRules.formatModifier(Dnd5eRules.abilityModifier(score))}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('point-buy-$ability-decrease'),
              tooltip: '降低$label',
              onPressed: score > 8 ? () => onChanged(score - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: Key('point-buy-$ability-increase'),
              tooltip: '提高$label',
              onPressed: canIncrease ? () => onChanged(score + 1) : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「熟练」步骤的技能选择器（`optionType: "skill"` 的**专门渲染器**）。
///
/// 值类型与交互口径与共享组件 [RuleChoiceSection] 一致：
/// - 选中值是有序 `List<String>`，顺序 = 点击顺序（即 `build.choices` 落库顺序）；
/// - 选中 / 取消算法只有 [toggleRuleChoiceSelection] 一处（共享组件同款）；
/// - [fixed]（背景预设）只展示、不可点：它是**背景**的身份，不进 `build.choices`。
///
/// 认领哪一步由 `RuleChoiceDefinition.dedicatedOptionSteps` 决定（`skill` → 4），
/// 本组件只负责"画哪一步被认领的那条选择"，不判断步骤。
///
/// 三种"不能选"的原因都在这里**可见**（不静默失败）：[blockedReason]（选择级
/// `requires` 不满足）、[unavailableReason]（候选为空 = 声明缺料）、
/// [unavailableSelected]（已选值不在候选集里 = 不会生效）。
class _SkillProficiencySection extends StatelessWidget {
  const _SkillProficiencySection({
    required this.selected,
    required this.onChanged,
    this.title = '熟练',
    this.options = const <String>[],
    this.fixed = const <String>{},
    this.minimum,
    this.maximum,
    this.repeatable = false,
    this.hint,
    this.blockedReason,
    this.unavailableReason,
    this.unavailableSelected = const <String>[],
  });

  /// 选择标题：规则驱动时是选择声明的 `label`（让用户看到"哪条选择"在问），
  /// 背景预设降级模式下是默认的「熟练」。
  final String title;
  final List<String> selected;
  final List<String> options;
  final Set<String> fixed;

  /// 必选项数（有专门选择的技能选择才有）；仅用于"还需选择 N 项"的提示，
  /// **不**参与选中值语义（校验由创建向导的 `_ruleChoiceIsComplete` 唯一承担）。
  final int? minimum;
  final int? maximum;
  final bool repeatable;

  /// 选择声明的 `help` 小字。
  final String? hint;

  /// 选择级 `requires` 不满足时的原因（`null` = 满足）：不满足时不渲染技能网格
  /// （选了也不生效），只显示原因。
  final String? blockedReason;

  /// 候选为空（声明里既没有 `options` 也没有匹配条目）时的原因：不能退化成
  /// "全技能随便选"——那些值不在候选集里，引擎会判 `notACandidate` 而不生效。
  final String? unavailableReason;

  /// 已选值里不在候选集内的项（引擎会判 `notACandidate`）：列出来，不静默丢弃。
  final List<String> unavailableSelected;

  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 规则驱动的技能选择一定有 `minimum`/`maximum`；背景预设降级模式两者都为
    // `null`（可自由编辑的既有行为）。不用 `options.isNotEmpty` 当判据：候选为空
    // 是"声明缺料"的错误状态，不能让它退化成"全技能随便选"。
    final constrained = maximum != null;
    final optionNames = options.toSet();
    final chosen = selected
        .where((skill) => optionNames.contains(skill) && !fixed.contains(skill))
        .toSet();
    final displayedNames = constrained
        ? <String>{...fixed, ...optionNames}
        : Dnd5eRules.skills.map((skill) => skill.name).toSet();
    final displayedSkills = Dnd5eRules.skills
        .where((skill) => displayedNames.contains(skill.name))
        .toList(growable: false);
    // 未受 `maximum` 约束（背景预设编辑模式）时上限 = 全部技能：`toggleRuleChoiceSelection`
    // 需要一个具体上限，但不能凭空捏造一个比"全部技能"更小的数。
    final toggleMaximum = maximum ?? Dnd5eRules.skills.length;
    final missing = minimum == null ? 0 : (minimum! - chosen.length);
    final blocked = blockedReason != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
              InputChip(
                avatar: const Icon(Icons.workspace_premium_outlined),
                label: Text(
                  constrained
                      ? '职业技能 ${chosen.length}/$maximum · 背景 ${fixed.length}'
                      : '熟练 ${selected.length} 项',
                ),
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (blocked || unavailableReason != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.block_outlined,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    // 选择级 `requires` 不满足优先：它是既有选中值"不生效"的真因。
                    blockedReason ?? unavailableReason!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (missing > 0) ...[
              const SizedBox(height: 4),
              Text(
                '还需选择 $missing 项技能',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in displayedSkills)
                  Builder(
                    builder: (context) {
                      // `fixed` 一律锁定：它现在承载"**背景条目自己声明**的技能熟练"
                      // （决策 D10）。背景没声明时 `fixed` 为空，网格照旧可自由编辑
                      // （公开构建没有背景条目，用户自己挑）。
                      final isFixed = fixed.contains(skill.name);
                      final isSelected = selected.contains(skill.name);
                      final atLimit =
                          constrained && chosen.length >= (maximum ?? 0);
                      final chip = FilterChip(
                        key: Key('standard-skill-${skill.name}-chip'),
                        avatar: isFixed
                            ? const Icon(Icons.lock_outline, size: 16)
                            : null,
                        label: Text(
                          '${skill.name} · ${Dnd5eRules.abilityLabels[skill.ability]}',
                        ),
                        selected: isSelected,
                        onSelected: isFixed || (!isSelected && atLimit)
                            ? null
                            : (_) => onChanged(
                                toggleRuleChoiceSelection(
                                  selected: selected,
                                  id: skill.name,
                                  repeatable: repeatable,
                                  maximum: toggleMaximum,
                                ),
                              ),
                      );
                      // 锁定的 chip 是 disabled、不可聚焦：必须给出**为什么**，
                      // 否则作者会以为是界面坏了（也是审查指出的可用性缺口）。
                      return isFixed
                          ? Tooltip(
                              message: '该技能熟练由背景条目声明，不能在这里取消；'
                                  '要改请改背景条目本身。',
                              child: chip,
                            )
                          : chip;
                    },
                  ),
              ],
            ),
          ],
          // 已选值不在候选集（技能声明改了 / 键来自旧存档）：引擎会判
          // `notACandidate` 而不生效。列出来，不静默丢弃也不冒充"已生效"。
          if (unavailableSelected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '已选但未生效：${unavailableSelected.join('、')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
