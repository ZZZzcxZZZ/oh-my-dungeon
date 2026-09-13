// character_editor_page.dart 的 part：构建器步骤骨架、页脚、摘要与审阅区。
part of 'character_editor_page.dart';

class _BuilderStepEditor extends StatelessWidget {
  const _BuilderStepEditor({
    required this.step,
    required this.stepLabel,
    required this.stepDescription,
    required this.nameController,
    required this.onNameChanged,
    required this.child,
  });

  final int step;
  final String stepLabel;
  final String stepDescription;
  final TextEditingController nameController;
  final ValueChanged<String> onNameChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '步骤 ${step + 1} · $stepLabel',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('standard-character-name-field'),
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '角色名',
                  hintText: '可以稍后修改',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                onChanged: onNameChanged,
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: KeyedSubtree(key: ValueKey(step), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuilderFooter extends StatelessWidget {
  const _BuilderFooter({
    required this.currentStep,
    required this.lastStep,
    required this.canCreate,
    required this.onPrevious,
    required this.onNext,
    required this.onContinueToFullSheet,
    required this.onCreate,
  });

  final int currentStep;
  final int lastStep;
  final bool canCreate;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onContinueToFullSheet;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final fullSheetButton = compact
                ? IconButton(
                    tooltip: '继续编辑完整角色卡',
                    onPressed: onContinueToFullSheet,
                    icon: const Icon(Icons.edit_note_outlined),
                  )
                : OutlinedButton.icon(
                    onPressed: onContinueToFullSheet,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('继续编辑完整角色卡'),
                  );
            final previousButton = compact
                ? IconButton(
                    tooltip: '上一步',
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back),
                  )
                : OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('上一步'),
                  );
            final primaryButton = currentStep == lastStep
                ? FilledButton.icon(
                    onPressed: canCreate ? onCreate : null,
                    icon: const Icon(Icons.check),
                    label: const Text('创建角色'),
                  )
                : FilledButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('下一步'),
                  );
            return Row(
              children: [
                fullSheetButton,
                const Spacer(),
                previousButton,
                const SizedBox(width: 12),
                if (compact) Expanded(child: primaryButton) else primaryButton,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BuilderSummaryPanel extends StatelessWidget {
  const _BuilderSummaryPanel({
    required this.summary,
    required this.review,
    required this.level,
    required this.className,
    required this.classEntry,
    this.classRules,
    required this.abilities,
    required this.selectedSpells,
    required this.selectedItems,
    required this.pendingChoices,
  });

  final String summary;
  final _StandardBuildReview review;
  final int level;
  final String className;
  final ContentEntry? classEntry;

  /// **已解析**的职业规则（由编辑器页面 `_resolveClassRules` 传入，带 disabled /
  /// pinned / 包 priority）。为 null 时退回按条目自身解析只是兜底，正常渲染路径必须
  /// 传——否则头部 HP 预览与编辑器其它位置（等级区、法术配额）口径不同（M）。
  final ResolvedClassRules? classRules;
  final Map<String, int> abilities;
  final int selectedSpells;
  final int selectedItems;
  final int pendingChoices;

  @override
  Widget build(BuildContext context) {
    final resolved =
        classRules ??
        Dnd5eRules.resolveClassRules(
          entryId: classEntry?.id,
          classSummary: classEntry?.name ?? className,
          structured: classEntry?.structured ?? const <String, Object?>{},
        );
    final hp = resolved.hitDie == null
        ? (Dnd5eRules.abilityModifier(
                    Dnd5eRules.abilityScore(abilities, 'con'),
                  ) *
                  level.clamp(1, 20))
              .clamp(1, 1 << 30)
        : Dnd5eRules.averageHitPointsForHitDie(
            hitDie: resolved.hitDie!,
            level: level,
            constitution: Dnd5eRules.abilityScore(abilities, 'con'),
          );
    final armorClass = Dnd5eRules.baseArmorClass(abilities);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('角色摘要', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(label: 'HP', value: '$hp'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(label: 'AC', value: '$armorClass'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: '熟练',
                  value: '+${Dnd5eRules.proficiencyBonus(level)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('完成度', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: review.progress),
          const SizedBox(height: 8),
          Text('${review.completed}/${review.total} 已完成'),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.backpack_outlined),
            title: const Text('装备'),
            trailing: Text('$selectedItems'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_fix_high_outlined),
            title: const Text('法术'),
            trailing: Text('$selectedSpells'),
          ),
          if (pendingChoices > 0)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.pending_actions_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: const Text('待完成选择'),
              trailing: Text('$pendingChoices'),
            ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _BuilderReviewStep extends StatelessWidget {
  const _BuilderReviewStep({
    required this.summary,
    required this.review,
    required this.pendingRuleChoices,
    required this.abilityMethodLabel,
  });

  final String summary;
  final _StandardBuildReview review;
  final List<_ActiveRuleChoice> pendingRuleChoices;
  final String abilityMethodLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('审核角色', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '完成度',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text('${review.completed}/${review.total} 已完成'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: review.progress),
        const SizedBox(height: 12),
        Card.filled(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('审核摘要'),
                subtitle: Text(summary),
              ),
              const Divider(height: 1),
              ListTile(
                dense: true,
                leading: const Icon(Icons.hexagon_outlined),
                title: const Text('属性生成来源'),
                trailing: Text(abilityMethodLabel),
              ),
              const Divider(height: 1),
              for (final check in review.checks)
                ListTile(
                  dense: true,
                  leading: Icon(
                    check.done
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(check.label),
                  trailing: Text(check.done ? '完成' : '待完成'),
                ),
            ],
          ),
        ),
        if (!review.isReady || pendingRuleChoices.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '创建前仍需完成',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final missing in review.missing)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline),
                      title: Text(missing),
                    ),
                  for (final choice in pendingRuleChoices)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.pending_actions_outlined),
                      title: Text(choice.definition.label),
                    ),
                ],
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Card.outlined(
            child: const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('创建前检查通过'),
              subtitle: Text('角色会保存所选资料条目的稳定引用与当前规则授予结果。'),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActiveRuleChoice {
  const _ActiveRuleChoice({
    required this.key,
    required this.sourceEntryId,
    required this.sourceName,
    required this.builderStep,
    required this.definition,
    this.level,
  });

  final String key;
  final String sourceEntryId;
  final String sourceName;

  /// 声明/继承来的步骤（`ruleChoiceBuilderStep` 的结果）。对专用 UI 选择只是
  /// 提示：**位置看 [renderStep]**。
  final int builderStep;
  final int? level;
  final RuleChoiceDefinition definition;

  /// 该选择在创建向导里的**渲染步骤**。
  ///
  /// 专用渲染器承担的选择（`skill` / `spell`）由 `optionType` **唯一**决定位置
  /// （`RuleChoiceDefinition.dedicatedOptionSteps`），[builderStep] 不参与；其余
  /// 选择按声明的 `builderStep` 走。位置计算与渲染判据都读这一处，避免
  /// "通用卡片排除它、专用渲染器又按别的步骤找它"造成的死锁。
  int get renderStep => definition.dedicatedOptionStep ?? builderStep;
}

class _StandardBuildReview {
  const _StandardBuildReview({required this.checks});

  factory _StandardBuildReview.from({
    required String name,
    required String className,
    required String species,
    required String background,
    required Map<String, int> abilityScores,
  }) {
    return _StandardBuildReview(
      checks: [
        const _BuildCheck(label: '来源', done: true),
        _BuildCheck(label: '职业', done: className.trim().isNotEmpty),
        _BuildCheck(
          label: '起源',
          done: species.trim().isNotEmpty && background.trim().isNotEmpty,
        ),
        _BuildCheck(label: '属性', done: _abilitiesAreValid(abilityScores)),
        _BuildCheck(label: '详情', done: name.trim().isNotEmpty),
      ],
    );
  }

  final List<_BuildCheck> checks;

  int get completed => checks.where((check) => check.done).length;
  int get total => checks.length;
  double get progress => completed / total;
  bool get isReady => completed == total;

  List<String> get missing {
    final result = <String>[];
    if (!checks.firstWhere((check) => check.label == '详情').done) {
      result.add('缺少角色名');
    }
    if (!checks.firstWhere((check) => check.label == '职业').done) {
      result.add('缺少职业');
    }
    if (!checks.firstWhere((check) => check.label == '起源').done) {
      result.add('缺少起源');
    }
    if (!checks.firstWhere((check) => check.label == '属性').done) {
      result.add('属性值需在 3-20');
    }
    return result;
  }

  static bool _abilitiesAreValid(Map<String, int> abilityScores) {
    return Dnd5eRules.abilityLabels.keys.every((ability) {
      final value = abilityScores[ability];
      return value != null && value >= 3 && value <= 20;
    });
  }
}

class _BuildCheck {
  const _BuildCheck({required this.label, required this.done});

  final String label;
  final bool done;
}
