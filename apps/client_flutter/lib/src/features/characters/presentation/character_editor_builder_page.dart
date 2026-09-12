// character_editor_page.dart 的 part：完整角色卡构建页及其状态。
part of 'character_editor_page.dart';

class _StandardBuildPage extends StatefulWidget {
  const _StandardBuildPage({
    required this.contentEntries,
    required this.onSubmit,
    required this.onContinueToFullSheet,
    this.onPickImage,
  });

  final List<ContentEntry> contentEntries;
  final Future<void> Function(QuickBuildSelection draft) onSubmit;
  final VoidCallback onContinueToFullSheet;
  final Future<({Uint8List bytes, String mimeType})?> Function()? onPickImage;

  @override
  State<_StandardBuildPage> createState() => _StandardBuildPageState();
}

class _StandardBuildPageState extends State<_StandardBuildPage> {
  static const _steps = ['职业', '背景', '物种', '属性', '熟练', '装备', '法术', '故事', '审核'];
  static const _stepIcons = [
    Icons.shield_outlined,
    Icons.history_edu_outlined,
    Icons.diversity_3_outlined,
    Icons.tune_outlined,
    Icons.workspace_premium_outlined,
    Icons.backpack_outlined,
    Icons.auto_fix_high_outlined,
    Icons.badge_outlined,
    Icons.fact_check_outlined,
  ];

  final _nameController = TextEditingController();
  final _appearanceController = TextEditingController();
  final _personalityController = TextEditingController();
  final _idealsController = TextEditingController();
  final _bondsController = TextEditingController();
  final _flawsController = TextEditingController();
  final _backstoryController = TextEditingController();
  final _privateNotesController = TextEditingController();
  int _currentStep = 0;
  late String _className;
  late String _species;
  late String _background;
  String? _classEntryId;
  String? _speciesEntryId;
  String? _backgroundEntryId;
  int _level = 1;
  final Set<String> _selectedSpellRefs = {};
  final List<Map<String, Object?>> _customSpells = [];
  final Set<String> _selectedItemRefs = {};
  final Map<String, List<String>> _ruleChoices = {};

  /// **背景预设**技能（`_presetSkillsForBackground`）。它只由背景决定，不是规则
  /// 选择：职业声明了 `optionType: "skill"` 时它是锁定的背景身份（`fixed`），
  /// 没有职业选择时（既有行为）它就是可编辑的技能集合本身。
  late Set<String> _backgroundSkillProficiencies;
  late Map<String, int> _abilityScores;
  late Map<String, TextEditingController> _abilityControllers;
  AbilityScoreMethod _abilityMethod = AbilityScoreMethod.standardArray;

  // 头像选择状态（规范 §头像来源：本地角色头像离线保存在客户端）。
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _pickingAvatar = false;
  String? _avatarPickError;

  String? get _avatarDataUrl {
    if (_avatarBytes != null && _avatarMimeType != null) {
      return 'data:$_avatarMimeType;base64,${base64Encode(_avatarBytes!)}';
    }
    return null;
  }

  Future<void> _pickAvatarImage() async {
    final picker = widget.onPickImage;
    if (picker == null) return;
    setState(() {
      _pickingAvatar = true;
      _avatarPickError = null;
    });
    try {
      final result = await picker();
      if (!mounted) return;
      if (result == null) {
        setState(() => _pickingAvatar = false);
        return;
      }
      if (result.bytes.length > 2 * 1024 * 1024) {
        setState(() {
          _pickingAvatar = false;
          _avatarPickError = '头像图片不能超过 2 MB';
        });
        return;
      }
      setState(() {
        _avatarBytes = result.bytes;
        _avatarMimeType = result.mimeType;
        _pickingAvatar = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingAvatar = false;
        _avatarPickError = '选择图片失败';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _className = _contentChoiceLabels('class', _defaultClassOptions).first;
    _species = _contentChoiceLabels('species', _defaultSpeciesOptions).first;
    _background = _contentChoiceLabels(
      'background',
      _defaultBackgroundOptions,
    ).first;
    _classEntryId = _entryIdFor('class', _className);
    _speciesEntryId = _entryIdFor('species', _species);
    _backgroundEntryId = _entryIdFor('background', _background);
    _backgroundSkillProficiencies = _presetSkillsForBackground(_background);
    _abilityScores = _presetAbilitiesForClass(_className);
    _abilityControllers = {
      for (final entry in Dnd5eRules.abilityLabels.entries)
        entry.key: TextEditingController(text: '${_abilityScores[entry.key]}'),
    };
    _applyRecommendedRuleChoices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appearanceController.dispose();
    _personalityController.dispose();
    _idealsController.dispose();
    _bondsController.dispose();
    _flawsController.dispose();
    _backstoryController.dispose();
    _privateNotesController.dispose();
    for (final controller in _abilityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryName = _nameController.text.trim().isEmpty
        ? '未命名角色'
        : _nameController.text.trim();
    final summary =
        '$summaryName / $_species / $_background / $_className / Lv.$_level';
    final review = _StandardBuildReview.from(
      name: _nameController.text,
      className: _className,
      species: _species,
      background: _background,
      abilityScores: _abilityScores,
    );
    final classOptions = _contentChoiceLabels('class', _defaultClassOptions);
    final speciesOptions = _contentChoiceLabels(
      'species',
      _defaultSpeciesOptions,
    );
    final backgroundOptions = _contentChoiceLabels(
      'background',
      _defaultBackgroundOptions,
    );
    final spellSelectionRules = SpellSelectionPolicy.rulesFor(
      classEntry: _entryById(_classEntryId),
      characterLevel: _level,
    );
    final eligibleSpellEntries = SpellSelectionPolicy.eligibleSpells(
      entries: widget.contentEntries,
      rules: spellSelectionRules,
    );
    final itemOptions = _contentChoiceLabelsForTypes(const [
      'equipment',
      'item',
    ], const []);
    final activeRuleChoices = _activeRuleChoices();
    final startingEquipment = _entryById(
      _classEntryId,
    )?.structured['startingEquipment'];
    final hasStructuredStartingEquipment =
        startingEquipment != null && '$startingEquipment'.trim().isNotEmpty;
    final visibleStepIndexes = <int>[
      0,
      1,
      2,
      3,
      4,
      if (itemOptions.isNotEmpty ||
          hasStructuredStartingEquipment ||
          activeRuleChoices.any((choice) => choice.builderStep == 5))
        5,
      if (_hasContentChoices('spell') ||
          activeRuleChoices.any((choice) => choice.builderStep == 6))
        6,
      7,
      8,
    ];
    final visibleStep = visibleStepIndexes.indexOf(_currentStep);
    // 所有选择一律按普通选择校验：数量、以及 `requires` 前置（前置不满足 = 未完成，
    // 且由选择区显示原因，不静默跳过）。**没有免检名单**：`usesDedicatedOptionUi`
    // 只决定渲染位置（技能网格 / 法术池），选中值同样进 `_ruleChoices`。
    final ruleChoicesAreValid = activeRuleChoices.every(_ruleChoiceIsComplete);
    final stepContent = _buildStepContent(
      context: context,
      classOptions: classOptions,
      speciesOptions: speciesOptions,
      backgroundOptions: backgroundOptions,
      spellEntries: eligibleSpellEntries,
      spellSelectionRules: spellSelectionRules,
      itemOptions: itemOptions,
      startingEquipment: startingEquipment,
      activeRuleChoices: activeRuleChoices,
      review: review,
      summary: summary,
    );

    return CharacterBuilderShell(
      title: '标准创建角色',
      destinations: [
        for (final index in visibleStepIndexes)
          CharacterBuilderDestination(
            id: index,
            label: _steps[index],
            icon: _stepIcons[index],
          ),
      ],
      selectedIndex: visibleStep,
      onSelected: (index) => _selectStep(visibleStepIndexes[index]),
      editor: _BuilderStepEditor(
        step: _currentStep,
        stepLabel: _steps[_currentStep],
        stepDescription: _stepDescription(_steps[_currentStep]),
        nameController: _nameController,
        onNameChanged: (_) => setState(() {}),
        child: stepContent,
      ),
      summary: _BuilderSummaryPanel(
        summary: summary,
        review: review,
        level: _level,
        className: _className,
        classEntry: _entryById(_classEntryId),
        abilities: _abilityScores,
        selectedSpells: _selectedSpellRefs.length,
        selectedItems: _selectedItemRefs.length,
        pendingChoices: activeRuleChoices
            .where((active) => !_ruleChoiceIsComplete(active))
            .length,
      ),
      bottomBar: SafeArea(
        child: _BuilderFooter(
          currentStep: visibleStep,
          lastStep: visibleStepIndexes.length - 1,
          canCreate: review.isReady && ruleChoicesAreValid,
          onPrevious: visibleStep == 0
              ? null
              : () => _selectStep(visibleStepIndexes[visibleStep - 1]),
          onNext: visibleStep == visibleStepIndexes.length - 1
              ? null
              : () => _selectStep(visibleStepIndexes[visibleStep + 1]),
          onContinueToFullSheet: widget.onContinueToFullSheet,
          onCreate: () => widget.onSubmit(_selection()),
        ),
      ),
    );
  }

  void _selectStep(int step) {
    setState(() => _currentStep = step.clamp(0, _steps.length - 1));
  }

  QuickBuildSelection _selection() {
    return QuickBuildSelection(
      name: _nameController.text,
      className: _className,
      species: _species,
      background: _background,
      level: _level,
      spellRefs: _selectedSpellRefs.toList(),
      itemRefs: _selectedItemRefs.toList(),
      abilities: Map.unmodifiable(_abilityScores),
      skillProficiencies: _backgroundSkillProficiencies.toList(growable: false),
      classEntry: _entryById(_classEntryId),
      classEntryId: _classEntryId,
      speciesEntryId: _speciesEntryId,
      backgroundEntryId: _backgroundEntryId,
      ruleChoices: {
        for (final entry in _ruleChoices.entries)
          entry.key: entry.value.toList(growable: false),
      },
      avatarUrl: _avatarDataUrl,
      appearance: _appearanceController.text,
      personalityTraits: _personalityController.text,
      ideals: _idealsController.text,
      bonds: _bondsController.text,
      flaws: _flawsController.text,
      backstory: _backstoryController.text,
      privateNotes: _privateNotesController.text,
      customSpells: List.unmodifiable(_customSpells),
    );
  }

  Widget _buildStepContent({
    required BuildContext context,
    required List<String> classOptions,
    required List<String> speciesOptions,
    required List<String> backgroundOptions,
    required List<ContentEntry> spellEntries,
    required SpellSelectionRules spellSelectionRules,
    required List<String> itemOptions,
    required Object? startingEquipment,
    required List<_ActiveRuleChoice> activeRuleChoices,
    required _StandardBuildReview review,
    required String summary,
  }) {
    // `skill` 选择由「熟练」步骤的技能选择器承担（任务 7 起选中值也写进
    // `_ruleChoices`），其余选择一律由共享组件渲染；判据的唯一实现点是
    // [RuleChoiceDefinition.usesDedicatedOptionUi]（**渲染**判据，不再是免检）。
    final choicesForCurrentStep = activeRuleChoices.where((choice) {
      return choice.builderStep == _currentStep &&
          !choice.definition.usesDedicatedOptionUi;
    });
    // `group` 相同的选择归一组（决策 D7）：组按首次声明顺序，无 group 的排最后。
    // 归组只有 `groupRuleChoiceSections` 一处实现。
    final ruleChoiceGroups = groupRuleChoiceSections<_ActiveRuleChoice>(
      choicesForCurrentStep,
      groupOf: (active) => active.definition.group,
      buildChoice: (active) => RuleChoiceSection(
        definition: active.definition,
        candidates: _candidatesFor(active),
        selected: _ruleChoices[active.key] ?? const <String>[],
        sourceLabel: _choiceSourceLabel(active),
        blockedReason: _blockedReasonFor(active),
        requiresContext: _requiresContextFor(active),
        onOpenEntry: _openEntry,
        onChanged: (next) => setState(() {
          _ruleChoices[active.key] = next;
          _applyRecommendedRuleChoices();
        }),
      ),
    );
    final ruleChoiceWidgets = RuleChoiceGroupedSections(
      groups: ruleChoiceGroups,
    );
    return switch (_currentStep) {
      0 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择职业',
            selected: _className,
            options: classOptions,
            sourceLabel: _hasContentChoices('class') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('class', name),
            onSelected: (value) => setState(() {
              _className = value;
              _classEntryId = _entryIdFor('class', value);
              _resetAbilityScoresForClass(value);
              _applyRecommendedRuleChoices();
            }),
          ),
          _StructuredRuleSummary(
            title: '职业规则摘要',
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'primaryAbility',
              'hitDie',
            ]),
          ),
          _LevelProgressionSection(
            level: _level,
            className: _className,
            classEntry: _entryById(_classEntryId),
            abilities: _abilityScores,
            onChanged: (value) => setState(() {
              _level = value;
              _applyRecommendedRuleChoices();
            }),
          ),
          ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(0, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      1 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择背景',
            selected: _background,
            options: backgroundOptions,
            sourceLabel: _hasContentChoices('background') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('background', name),
            onSelected: (value) => setState(() {
              _background = value;
              _backgroundEntryId = _entryIdFor('background', value);
              _backgroundSkillProficiencies = _presetSkillsForBackground(value);
              _applyRecommendedRuleChoices();
            }),
          ),
          ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(1, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      2 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChoiceSection(
            title: '选择物种',
            selected: _species,
            options: speciesOptions,
            sourceLabel: _hasContentChoices('species') ? '来自资料库' : null,
            onOpenOption: (name) => _openEntryByTypeAndName('species', name),
            onSelected: (value) => setState(() {
              _species = value;
              _speciesEntryId = _entryIdFor('species', value);
              _applyRecommendedRuleChoices();
            }),
          ),
          ruleChoiceWidgets,
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(2, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      3 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('设置属性', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _AbilityScoreSection(
            method: _abilityMethod,
            scores: _abilityScores,
            controllers: _abilityControllers,
            onMethodChanged: _changeAbilityMethod,
            onApplyRecommended: () => setState(
              () => _setAbilityScores(_presetAbilitiesForClass(_className)),
            ),
            onRoll: _rollAbilityScores,
            onChanged: (ability, value) =>
                setState(() => _abilityScores[ability] = value),
          ),
          // 决策 D7：`builderStep: "abilities"` 也必须有渲染位置，否则
          // `allowedBuilderSteps` 放行的选择会"看不见却阻塞创建"。
          ruleChoiceWidgets,
        ],
      ),
      4 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StructuredRuleSummary(
            title: '职业熟练摘要',
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'savingThrows',
              'skills',
              'weaponProficiency',
              'armorProficiency',
            ]),
          ),
          ruleChoiceWidgets,
          ..._skillProficiencySections(),
          _RuleGrantPreview(
            entries: _ruleEntriesForStep(4, activeRuleChoices),
            level: _level,
          ),
        ],
      ),
      5 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StructuredRuleSummary(
            title: '职业初始装备',
            items: _classSummaryItems(_entryById(_classEntryId), const [
              'startingEquipment',
            ]),
          ),
          ruleChoiceWidgets,
          if (ruleChoiceGroups.isEmpty) ...[
            _EquipmentBudgetSummary(
              startingEquipment: startingEquipment,
              selectedNames: _selectedItemRefs,
              entries: widget.contentEntries
                  .where(
                    (entry) =>
                        entry.type == 'equipment' || entry.type == 'item',
                  )
                  .toList(growable: false),
            ),
            _MultiChoiceSection(
              title: '选择装备',
              selected: _selectedItemRefs,
              options: itemOptions,
              sourceLabel:
                  _hasContentChoicesForTypes(const ['equipment', 'item'])
                  ? '来自资料库'
                  : null,
              emptyLabel: '资料库中暂无装备；规则方案仍会自动应用。',
              onOpenOption: (name) =>
                  _openEntryByTypesAndName(const ['equipment', 'item'], name),
              onChanged: (next) =>
                  setState(() => _replaceSet(_selectedItemRefs, next)),
              maximum: StructuredClassRules.startingEquipmentChoice(
                _entryById(_classEntryId),
              )?.maximum,
            ),
          ],
        ],
      ),
      6 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ruleChoiceWidgets,
          if (ruleChoiceGroups.isEmpty)
            _SpellChoiceSection(
              entries: spellEntries,
              selected: _selectedSpellRefs,
              onChanged: (next) =>
                  setState(() => _replaceSet(_selectedSpellRefs, next)),
              maximumCantrips: spellSelectionRules.maximumCantrips,
              maximumLeveledSpells: spellSelectionRules.maximumLeveledSpells,
              maximumSpellLevel: spellSelectionRules.maximumSpellLevel,
              automaticRulesConfigured: spellSelectionRules.configured,
              customSpells: _customSpells,
              onAddCustom: _addCustomSpell,
              onRemoveCustom: (index) =>
                  setState(() => _customSpells.removeAt(index)),
              onOpenEntry: (entry) => _openEntry(entry),
            ),
        ],
      ),
      // 决策 D7：`builderStep: "details"` 也必须有渲染位置（示例包
      // `asi-or-feat` 就是这一类），否则选择区不可见却仍阻塞创建。
      7 => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ruleChoiceWidgets,
          _DetailsStep(
            name: _nameController.text,
            avatarBytes: _avatarBytes,
            isPickingAvatar: _pickingAvatar,
            avatarPickError: _avatarPickError,
            onPickAvatar: _pickAvatarImage,
            appearanceController: _appearanceController,
            personalityController: _personalityController,
            idealsController: _idealsController,
            bondsController: _bondsController,
            flawsController: _flawsController,
            backstoryController: _backstoryController,
            privateNotesController: _privateNotesController,
          ),
        ],
      ),
      8 => _BuilderReviewStep(
        summary: summary,
        review: review,
        abilityMethodLabel: _abilityMethodLabel(_abilityMethod),
        pendingRuleChoices: activeRuleChoices
            .where((active) => !_ruleChoiceIsComplete(active))
            .toList(growable: false),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  static String _stepDescription(String step) {
    return switch (step) {
      '职业' => '选择职业、等级和职业资源。',
      '背景' => '选择背景、技能与起源专长。',
      '物种' => '选择物种与物种特性。',
      '属性' => '标准数组、购点、掷骰或自定义。',
      '熟练' => '技能、工具、武器、防具与豁免。',
      '装备' => '职业装备、金币购买或自定义装备。',
      '法术' => '戏法、准备法术、法术位和专注。',
      '故事' => '头像、外貌、性格、牵绊与背景故事。',
      '审核' => '检查缺失项、来源和手动覆盖。',
      _ => '',
    };
  }

  static String _abilityMethodLabel(AbilityScoreMethod method) {
    return switch (method) {
      AbilityScoreMethod.standardArray => '标准数组',
      AbilityScoreMethod.pointBuy => '27 点购点',
      AbilityScoreMethod.rolled => '随机',
    };
  }

  List<String> _contentChoiceLabels(String type, List<String> fallback) {
    return _contentChoiceLabelsForTypes([type], fallback);
  }

  List<String> _contentChoiceLabelsForTypes(
    List<String> types,
    List<String> fallback,
  ) {
    final labels = <String>{
      ...widget.contentEntries
          .where((entry) => types.contains(entry.type))
          .map((entry) => entry.name.trim())
          .where((name) => name.isNotEmpty),
    }.toList()..sort();
    return labels.isEmpty ? fallback : labels;
  }

  bool _hasContentChoices(String type) {
    return _hasContentChoicesForTypes([type]);
  }

  bool _hasContentChoicesForTypes(List<String> types) {
    return widget.contentEntries.any(
      (entry) => types.contains(entry.type) && entry.name.trim().isNotEmpty,
    );
  }

  ContentEntry? _entryById(String? entryId) {
    if (entryId == null) return null;
    return widget.contentEntries
        .where((entry) => entry.id == entryId)
        .firstOrNull;
  }

  String? _entryIdFor(String type, String name) {
    for (final entry in widget.contentEntries) {
      if (entry.type == type && entry.name.trim() == name.trim()) {
        return entry.id;
      }
    }
    return null;
  }

  List<_ActiveRuleChoice> _activeRuleChoices() {
    final queue = <({String entryId, int builderStep})>[
      if (_classEntryId != null) (entryId: _classEntryId!, builderStep: 0),
      if (_speciesEntryId != null) (entryId: _speciesEntryId!, builderStep: 2),
      if (_backgroundEntryId != null)
        (entryId: _backgroundEntryId!, builderStep: 1),
    ];
    final visited = <String>{};
    final result = <_ActiveRuleChoice>[];
    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visited.add(current.entryId)) continue;
      final entryId = current.entryId;
      final entry = widget.contentEntries
          .where((candidate) => candidate.id == entryId)
          .firstOrNull;
      final rules = entry?.rules;
      if (entry == null || rules == null) continue;
      for (final definition in rules.choices) {
        final builderStep = ruleChoiceBuilderStep(
          definition.builderStep,
          inheritedStep: current.builderStep,
        );
        result.add(
          _ActiveRuleChoice(
            key: ruleUnitKey(entry.id, definition.id, null),
            sourceEntryId: entry.id,
            sourceName: entry.name,
            builderStep: builderStep,
            definition: definition,
          ),
        );
      }
      for (final progression in rules.progression) {
        // 一个步骤可覆盖多个等级（`levels`）：每个已达等级都是**独立**的生效单元
        // （§3.5 "同一批效果在多个等级重复生效"），选择也要每级各问一次；
        // 键必须带上等级，否则同一份选择会被折叠成一次、且与引擎判断不一致。
        final reachedLevels = progression.levels
            .where((level) => level <= _level)
            .toList(growable: false);
        for (final reachedLevel in reachedLevels) {
          for (final definition in progression.choices) {
            final builderStep = ruleChoiceBuilderStep(
              definition.builderStep,
              inheritedStep: current.builderStep,
            );
            result.add(
              _ActiveRuleChoice(
                key: ruleUnitKey(entry.id, definition.id, reachedLevel),
                sourceEntryId: entry.id,
                sourceName: entry.name,
                builderStep: builderStep,
                level: reachedLevel,
                definition: definition,
              ),
            );
          }
        }
      }
      for (final active in result.where(
        (choice) => choice.sourceEntryId == entry.id,
      )) {
        final selected = _ruleChoices[active.key] ?? const <String>[];
        queue.addAll(
          selected.map(
            (selectedId) =>
                (entryId: selectedId, builderStep: active.builderStep),
          ),
        );
      }
    }
    return result;
  }

  void _openEntryByTypeAndName(String type, String name) {
    _openEntryByTypesAndName([type], name);
  }

  void _openEntry(ContentEntry entry) {
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  Future<void> _addCustomSpell() async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (dialogContext) => const _CustomSpellDialog(),
    );
    if (result != null && mounted) {
      setState(() => _customSpells.add(result));
    }
  }

  List<ContentEntry> _ruleEntriesForStep(
    int step,
    List<_ActiveRuleChoice> activeChoices,
  ) {
    final ids = <String>{
      if (step == 0 && _classEntryId != null) _classEntryId!,
      if (step == 2 && _speciesEntryId != null) _speciesEntryId!,
      if (step == 1 && _backgroundEntryId != null) _backgroundEntryId!,
      for (final choice in activeChoices.where(
        (candidate) => candidate.builderStep == step,
      ))
        ...?_ruleChoices[choice.key],
    };
    return widget.contentEntries
        .where((entry) => ids.contains(entry.id))
        .toList(growable: false);
  }

  void _openEntryByTypesAndName(List<String> types, String name) {
    final entry = widget.contentEntries
        .where(
          (candidate) =>
              types.contains(candidate.type) &&
              candidate.name.trim() == name.trim(),
        )
        .firstOrNull;
    if (entry == null) return;
    showContentEntryPreviewDialog(
      context,
      entry: entry,
      entries: widget.contentEntries,
    );
  }

  List<RuleChoiceCandidate> _candidatesFor(_ActiveRuleChoice active) {
    return RuleChoiceSemantics.candidatesFor(
      active.definition,
      entries: _entriesById,
      sourceEntryId: active.sourceEntryId,
    );
  }

  String _choiceSourceLabel(_ActiveRuleChoice active) {
    return active.level == null
        ? active.sourceName
        : '${active.sourceName} · 等级 ${active.level}';
  }

  Map<String, ContentEntry> get _entriesById => {
    for (final entry in widget.contentEntries) entry.id: entry,
  };

  RuleChoiceRequiresContext _requiresContextFor(_ActiveRuleChoice active) =>
      RuleChoiceRequiresContext(
        sourceEntryId: active.sourceEntryId,
        selectedByKey: _ruleChoices,
        abilities: _abilityScores,
        entries: _entriesById,
      );

  /// 选择级 `requires` 不满足时的原因文案；满足时为 `null`。判定与文案的唯一
  /// 实现点是 `ruleChoiceBlockedReason`（`RuleChoiceSemantics.requiresSatisfied`）。
  String? _blockedReasonFor(_ActiveRuleChoice active) => ruleChoiceBlockedReason(
    active.definition.requires,
    context: _requiresContextFor(active),
  );

  /// 一条选择是否**真的完成**：前置满足 + 数量在 `minimum`–`maximum` 之间。
  ///
  /// `ruleChoicesAreValid` / 摘要的 pending 计数 / 审核页清单共用它一处，
  /// 不得各自再写一套判断。
  bool _ruleChoiceIsComplete(_ActiveRuleChoice active) {
    final selected = _ruleChoices[active.key] ?? const <String>[];
    return _blockedReasonFor(active) == null &&
        selected.length >= active.definition.minimum &&
        selected.length <= active.definition.maximum;
  }

  void _applyRecommendedRuleChoices() {
    final resolver = RuleChoiceResolver(
      entries: {for (final entry in widget.contentEntries) entry.id: entry},
    );
    var changed = true;
    while (changed) {
      changed = false;
      for (final active in _activeRuleChoices()) {
        // `recommendedEntryIds` 只指向**条目**，而推荐值必须落在候选集里：
        // `recommendedFor` 已按候选过滤（技能选择没有条目候选时自然为空），
        // 因此不再需要"跳过专门 UI"的免检分支。
        if ((_ruleChoices[active.key] ?? const <String>[]).isNotEmpty) continue;
        final recommended = resolver.recommendedFor(
          active.definition,
          sourceEntryId: active.sourceEntryId,
        );
        if (recommended.isEmpty) continue;
        _ruleChoices[active.key] = recommended.toList(growable: false);
        changed = true;
      }
    }
  }

  /// 「熟练」步骤的专门渲染器（`usesDedicatedOptionUi` 的选择 = `optionType:
  /// "skill"`）：每条技能选择一组技能网格，候选与共享组件同源
  /// （`RuleChoiceSemantics.candidatesFor`），选中值写进 `_ruleChoices`。
  ///
  /// 职业**没有**任何技能选择时保持既有行为：同一组件降级为"背景预设编辑"
  /// （全技能网格、写回 [_backgroundSkillProficiencies]）——这是历史 UX，不是
  /// 第二种"职业技能选择"实现（候选、交互、落库都由同一处承担）。
  List<Widget> _skillProficiencySections() {
    final skillChoices = _activeRuleChoices()
        .where(
          (active) =>
              active.builderStep == 4 && active.definition.usesDedicatedOptionUi,
        )
        .toList(growable: false);
    if (skillChoices.isEmpty) {
      return [
        _SkillProficiencySection(
          selected: _backgroundSkillProficiencies.toList(growable: false),
          onChanged: (next) =>
              setState(() => _backgroundSkillProficiencies = next.toSet()),
        ),
      ];
    }
    return [
      for (final active in skillChoices)
        _SkillProficiencySection(
          selected: _ruleChoices[active.key] ?? const <String>[],
          options: _candidatesFor(
            active,
          ).map((candidate) => candidate.label).toList(growable: false),
          minimum: active.definition.minimum,
          maximum: active.definition.maximum,
          repeatable: active.definition.repeatable,
          fixed: _backgroundSkillProficiencies,
          onChanged: (next) => setState(() {
            _ruleChoices[active.key] = next;
            _applyRecommendedRuleChoices();
          }),
        ),
    ];
  }

  void _replaceSet(Set<String> target, Set<String> next) {
    target
      ..clear()
      ..addAll(next);
  }

  void _changeAbilityMethod(AbilityScoreMethod method) {
    setState(() {
      _abilityMethod = method;
      if (method == AbilityScoreMethod.rolled) {
        _setAbilityScores(
          AbilityScoreGenerator.assignByPriority(
            scores: _abilityScores.values.toList(growable: false),
            priorities: _abilityPrioritiesForClass(_className),
          ),
        );
      } else {
        _setAbilityScores(_presetAbilitiesForClass(_className));
      }
    });
  }

  void _rollAbilityScores() {
    final random = Random.secure();
    final rolled = AbilityScoreGenerator.rollSix(nextInt: random.nextInt);
    setState(() {
      _abilityMethod = AbilityScoreMethod.rolled;
      _setAbilityScores(
        AbilityScoreGenerator.assignByPriority(
          scores: rolled,
          priorities: _abilityPrioritiesForClass(_className),
        ),
      );
    });
  }

  List<String> _abilityPrioritiesForClass(String className) {
    final preset = _presetAbilitiesForClass(className).entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return preset.map((entry) => entry.key).toList(growable: false);
  }

  void _setAbilityScores(Map<String, int> scores) {
    _abilityScores = Map<String, int>.from(scores);
    for (final entry in _abilityScores.entries) {
      _abilityControllers[entry.key]?.text = '${entry.value}';
    }
  }

  /// 推荐属性预设：**按条目身份 / 档案 slug 取键**
  /// （[QuickBuildService.editorAbilityPresetFor]），不再写死中文职业名。
  Map<String, int> _presetAbilitiesForClass(String className) =>
      QuickBuildService.editorAbilityPresetFor(
        classEntryId: _entryIdFor('class', className),
        className: className,
      );

  void _resetAbilityScoresForClass(String className) {
    final scores = _abilityMethod == AbilityScoreMethod.rolled
        ? AbilityScoreGenerator.assignByPriority(
            scores: _abilityScores.values.toList(growable: false),
            priorities: _abilityPrioritiesForClass(className),
          )
        : _presetAbilitiesForClass(className);
    _setAbilityScores(scores);
  }

  Set<String> _presetSkillsForBackground(String background) {
    final normalized = background.toLowerCase();
    if (normalized.contains('贤者') || normalized.contains('sage')) {
      return {'奥秘', '历史'};
    }
    if (normalized.contains('罪犯') || normalized.contains('criminal')) {
      return {'欺瞒', '隐匿'};
    }
    if (normalized.contains('侍僧') ||
        normalized.contains('侍祭') ||
        normalized.contains('acolyte')) {
      return {'洞悉', '宗教'};
    }
    return {'运动', '威吓'};
  }
}
